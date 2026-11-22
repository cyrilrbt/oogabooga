#!/usr/bin/env python3
"""Lower the repository's bounded AArch64 engine dialect to native AMD64.

This is a build-time assembler backend, not an emulator. Unknown instructions
fail the build. The shared handwritten engine remains the source of truth.
"""
import math
import argparse
import ast
from pathlib import Path
import re
import struct
ROOT = Path(__file__).resolve().parents[2]

def args(text):
    result, start, depth, quote = ([], 0, 0, None)
    for i, c in enumerate(text):
        if quote:
            if c == quote and (i == 0 or text[i - 1] != '\\'):
                quote = None
        elif c in '"\'':
            quote = c
        elif c in '([':
            depth += 1
        elif c in ')]':
            depth -= 1
        elif c == ',' and depth == 0:
            result.append(text[start:i].strip())
            start = i + 1
    result.append(text[start:].strip())
    return result

def uncomment(line):
    quote = None
    escaped = False
    for i, char in enumerate(line):
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif line[i:i + 2] == "//":
            return line[:i].strip()
    return line.strip()


class Backend:
    # SysV argument registers also hold x0..x5. Keep hot callee-saved values
    # and x9 in real registers; other virtual registers spill per invocation.
    regs = {0: 'rdi', 1: 'rsi', 2: 'rdx', 3: 'rcx', 4: 'r8', 5: 'r9', 9: 'r10', 19: 'rbx', 20: 'r12', 21: 'r13', 22: 'r14', 23: 'r15'}
    low = {'rax': 'eax', 'r11': 'r11d', 'rdi': 'edi', 'rsi': 'esi', 'rdx': 'edx', 'rcx': 'ecx', 'rbx': 'ebx', 'rsp': 'esp', **{f'r{i}': f'r{i}d' for i in range(8, 16)}}
    externals = {'calloc', 'free', 'malloc', 'memchr', 'memcmp', 'memcpy', 'memmem', 'memset', 'realloc', 'strcasecmp', 'strcasestr', 'strcmp', 'strlen', 'strncasecmp', 'strndup', 'strnlen', 'strstr', 'strtod', 'strtol', 'clock_gettime_nsec_np'}
    conditions = {'eq': 'e', 'ne': 'ne', 'hs': 'ae', 'cs': 'ae', 'lo': 'b', 'cc': 'b', 'hi': 'a', 'ls': 'be', 'lt': 'l', 'le': 'le', 'gt': 'g', 'ge': 'ge', 'vs': 'o', 'vc': 'no', 'mi': 's', 'pl': 'ns'}

    def __init__(self):
        self.constants, self.macros, self.lines = ({}, {}, [])
        self.serial = 0
        self.symbols, self.globals, self.functions = ({}, set(), set())
        self.c_abi_args = {}
        self.output = []

    def unique(self, stem='next'):
        self.serial += 1
        return f'.Looga_{stem}_{self.serial}'

    def expr(self, value):
        value = value.strip().removeprefix('#')

        def run(node):
            if isinstance(node, ast.Constant) and type(node.value) is int:
                return node.value
            if isinstance(node, ast.Name):
                return self.constants[node.id]
            if isinstance(node, ast.UnaryOp):
                n = run(node.operand)
                if isinstance(node.op, ast.USub): return -n
                if isinstance(node.op, ast.Invert): return ~n
                if isinstance(node.op, ast.UAdd): return n
                raise ValueError(f'unsupported unary constant {value}')
            if isinstance(node, ast.BinOp):
                a, b = (run(node.left), run(node.right))
                operations = {ast.Add: lambda: a + b, ast.Sub: lambda: a - b, ast.Mult: lambda: a * b, ast.LShift: lambda: a << b, ast.RShift: lambda: a >> b, ast.BitOr: lambda: a | b, ast.BitAnd: lambda: a & b, ast.BitXor: lambda: a ^ b, ast.FloorDiv: lambda: a // b}
                return operations[type(node.op)]()
            if isinstance(node, ast.Compare) and len(node.ops) == 1:
                a, b = (run(node.left), run(node.comparators[0]))
                comparisons = {ast.Eq: a == b, ast.NotEq: a != b, ast.Lt: a < b,
                               ast.LtE: a <= b, ast.Gt: a > b, ast.GtE: a >= b}
                if type(node.ops[0]) not in comparisons:
                    raise ValueError(f'unsupported constant comparison {value}')
                return int(comparisons[type(node.ops[0])])
            raise ValueError(f'unsupported constant {value}')
        return run(ast.parse(value, mode='eval').body)

    def read(self, path):
        self.expand([(path, i, uncomment(s)) for i, s in enumerate((ROOT / path).read_text().splitlines(), 1)])

    def expand(self, lines):
        i = 0
        active = [True]
        while i < len(lines):
            path, number, s = lines[i]
            i += 1
            if not s:
                continue
            if s.startswith('.macro '):
                head = s[7:].split(None, 1)
                params = args(head[1]) if len(head) > 1 else []
                body = []
                while i < len(lines) and lines[i][2] != '.endm':
                    body.append(lines[i])
                    i += 1
                i += 1
                if active[-1]:
                    self.macros[head[0]] = (params, body)
                continue
            if s.startswith(('.ifdef ', '.ifndef ')):
                directive, name = s.split(None, 1)
                defined = name in self.constants
                active.append(active[-1] and (defined if directive == '.ifdef' else not defined))
                continue
            if s.startswith('.if '):
                active.append(active[-1] and bool(self.expr(s[4:])))
                continue
            if s == '.else':
                active[-1] = active[-2] and (not active[-1])
                continue
            if s == '.endif':
                active.pop()
                continue
            if not active[-1]:
                continue
            if s.startswith('.include '):
                self.read(Path(s.split('"')[1]))
                continue
            if s.startswith('.set '):
                name, value = args(s[5:])
                self.constants[name] = self.expr(value)
                continue
            head = s.split(None, 1)
            op = head[0]
            if op == 'CORE_C_ABI_ARGS':
                name, count = args(head[1])
                count = self.expr(count)
                if not 0 <= count <= 8:
                    raise ValueError(f'unsupported C integer arity: {name}, {count}')
                self.c_abi_args[name] = count
                continue
            if op == 'CALLBACK':
                self.lines.append((path, number, 'ooga_callback ' + head[1]))
                continue
            if op in ('ADDR', 'LOAD', 'STORE'):
                self.lines.append((path, number, 'ooga_' + op.lower() + ' ' + head[1]))
                continue
            if op in self.macros:
                params, body = self.macros[op]
                values = args(head[1]) if len(head) > 1 else []
                if len(params) != len(values):
                    raise ValueError(s)
                replacements = dict(zip(params, values))
                token = self.unique('macro').replace('.', '_')
                expanded = []
                for p, n, t in body:
                    t = t.replace('\\@', token)
                    t = re.sub('\\\\([A-Za-z_][A-Za-z_0-9]*)', lambda m: replacements[m[1]], t)
                    expanded.append((path, number, t))
                self.expand(expanded)
                continue
            self.lines.append((path, number, s))

    def discover(self):
        section = 'text'
        for path, n, s in self.lines:
            if s.startswith('.section'):
                section = 'data'
            elif s == '.text':
                section = 'text'
            elif s.startswith('.globl '):
                self.globals.update(args(s[7:]))
            m = re.match('^([A-Za-z_][\\w]*):', s)
            if m:
                name = m[1]
                key = name if name.startswith('_') else (str(path), name)
                self.symbols[key] = ('ooga_core_' + name[1:] if section == 'text' else name[1:]) if name.startswith('_') else 'ooga_' + re.sub(r'[^A-Za-z0-9_]', '_', str(path)) + '_' + name
                if section == 'text' and name.startswith('_'):
                    self.functions.add(name)
        for name in self.globals:
            if name not in self.functions:
                self.symbols[name] = name.removeprefix('_')

    def symbol(self, name, path):
        if name in self.symbols:
            return self.symbols[name]
        key = (str(path), name)
        if key in self.symbols:
            return self.symbols[key]
        if re.fullmatch('\\d+[fb]', name):
            return name
        if name in self.constants:
            return str(self.constants[name])
        raise ValueError(f'unknown symbol {name}')

    def emit(self, *lines):
        self.output.extend(('    ' + line for line in lines))

    def loc(self, reg, bits=None):
        if reg in ('xzr', 'wzr'):
            return '0'
        if reg == 'sp':
            return 'rsp' if bits != 32 else 'esp'
        m = re.fullmatch('([xw])(\\d+)', reg)
        if not m:
            raise ValueError(f'not an integer register: {reg}')
        i = int(m[2])
        if not 0 <= i <= 30:
            raise ValueError(f'invalid integer register {reg}')
        bits = bits or (32 if m[1] == 'w' else 64)
        if i in self.regs:
            return self.low[self.regs[i]] if bits == 32 else self.regs[i]
        return f"{('dword' if bits == 32 else 'qword')} ptr [rbp + {i * 8}]"

    def load(self, scratch, operand, bits=64):
        target = self.low[scratch] if bits == 32 else scratch
        if operand.startswith('#'):
            value = self.expr(operand) & (1 << bits) - 1
            self.emit(f'mov {target}, {value}')
        else:
            self.emit(f'mov {target}, {self.loc(operand, bits)}')

    def store(self, reg, scratch='rax', bits=None):
        if reg in ('xzr', 'wzr'):
            return
        bits = bits or (32 if reg.startswith('w') else 64)
        if bits == 32:
            # A W write zero-extends its entire X register, including spills.
            self.emit(f'mov {self.low[scratch]}, {self.low[scratch]}')
            self.emit(f"mov {self.loc('x' + reg[1:])}, {scratch}")
        else:
            self.emit(f'mov {self.loc(reg)}, {scratch}')

    def flags(self):
        self.emit('pushfq', 'pop qword ptr [rbp + 448]')

    def restore_flags(self):
        self.emit('push qword ptr [rbp + 448]', 'popfq')

    def shift(self, scratch, spec, bits):
        kind, value = spec.split(None, 1)
        operation = {'lsl': 'shl', 'lsr': 'shr', 'asr': 'sar', 'ror': 'ror'}[kind]
        reg = self.low[scratch] if bits == 32 else scratch
        if value.startswith('#'):
            self.emit(f'{operation} {reg}, {self.expr(value)}')
        else:
            self.emit('mov qword ptr [rbp + 456], rcx')
            self.load('rcx', value)
            self.emit(f'{operation} {reg}, cl', 'mov rcx, qword ptr [rbp + 456]')

    def address(self, memory):
        pre = memory.endswith('!')
        memory = memory.removesuffix('!')
        assert memory.startswith('[') and memory.endswith(']'), memory
        parts = args(memory[1:-1])
        base = parts[0]
        self.load('rax', base)
        if len(parts) > 1:
            self.load('r11', parts[1])
            if len(parts) > 2:
                self.shift('r11', parts[2], 64)
            self.emit('add rax, r11')
        if pre:
            self.store(base)
        return base

    def fp_load(self, target, source):
        if source.startswith('#'):
            value = struct.unpack('<Q', struct.pack('<d', float(source[1:])))[0]
            self.emit(f'mov rax, {value}', f'movq {target}, rax')
            return
        if not re.fullmatch(r'd(?:[0-9]|[12][0-9]|3[01])', source):
            raise ValueError(f'unsupported floating register {source}')
        i = int(source[1:])
        self.emit(f'movsd {target}, ' + (f'xmm{i}' if i < 8 else f'qword ptr [rbp + {256 + (i - 8) * 8}]'))

    def fp_store(self, dest, source='xmm14'):
        if not re.fullmatch(r'd(?:[0-9]|[12][0-9]|3[01])', dest):
            raise ValueError(f'unsupported floating register {dest}')
        i = int(dest[1:])
        self.emit('movsd ' + (f'xmm{i}' if i < 8 else f'qword ptr [rbp + {256 + (i - 8) * 8}]') + f', {source}')

    def external(self, target, tail=False):
        target = target.removeprefix('_')
        if target not in self.externals:
            raise ValueError(f'unsupported external ABI {target}')
        if target == 'clock_gettime_nsec_np':
            target = 'oogabooga_clock_gettime_nsec'
        after = self.unique('call_return')
        if not tail:
            self.emit(f'lea rax, [rip + {after}]', 'mov qword ptr [rbp + 240], rax')
        self.emit('mov qword ptr [rbp + 488], rsp', 'and rsp, -16', *(['xor eax, eax'] if target in ('g_strconcat','g_string_append_printf','g_strdup_printf','gtk_dialog_new_with_buttons') else []), f'call {target}@PLT', 'mov rsp, qword ptr [rbp + 488]', 'mov rdi, rax')
        if tail:
            self.emit('jmp qword ptr [rbp + 240]')
        else:
            self.output.append(after + ':')

    def instruction(self, op, a, path):
        if op in ('ooga_addr', 'ooga_load', 'ooga_store', 'ooga_callback'):
            reg, label = a
            symbol = label.removeprefix("_") if op == "ooga_callback" and label.removeprefix("_") in self.externals else self.symbol(label, path)
            if op == 'ooga_callback':
                if label.removeprefix("_") not in self.externals and (label not in self.functions or label not in self.globals):
                    raise ValueError(f'callback needs a public entry: {label}')
                if label.removeprefix("_") in self.externals:
                    self.emit(f'mov rax, qword ptr [rip + {label.removeprefix("_")}@GOTPCREL]')
                else:
                    self.emit(f'lea rax, [rip + {label.removeprefix("_")}]')
                self.store(reg)
            elif op == 'ooga_addr':
                self.emit(f'lea rax, [rip + {symbol}]')
                self.store(reg)
            elif op == 'ooga_load':
                self.emit(f'mov rax, qword ptr [rip + {symbol}]')
                self.store(reg)
            else:
                self.load('rax', reg)
                self.emit(f'mov qword ptr [rip + {symbol}], rax')
            return
        if op == 'bfi':
            width = 32 if a[0].startswith('w') else 64
            shift, count = self.expr(a[2]), self.expr(a[3])
            if shift < 0 or count < 1 or shift+count > width:
                raise ValueError('invalid bitfield insertion')
            mask = (1 << count)-1
            self.load('rax', a[1])
            self.emit(f'mov r11, {mask}', 'and rax, r11', f'shl rax, {shift}', 'mov qword ptr [rbp + 456], rax')
            self.load('rax', a[0])
            self.emit(f'mov r11, {((1 << width)-1) ^ (mask << shift)}', 'and rax, r11', 'or rax, qword ptr [rbp + 456]')
            self.store(a[0])
            return
        if op in ('fmadd', 'frintm'):
            # libm provides fused rounding on baseline SSE2 CPUs as well.
            self.fp_load('xmm14', a[1])
            if op == 'fmadd':
                self.fp_load('xmm15', a[2])
                self.fp_load('xmm13', a[3])
            saved = ['rdi','rsi','rdx','rcx','r8','r9','r10']
            self.emit('mov qword ptr [rbp + 488], rsp', 'and rsp, -16', 'sub rsp, 128')
            for i, register in enumerate(saved):
                self.emit(f'mov qword ptr [rsp + {i*8}], {register}')
            for i in range(8):
                self.emit(f'movsd qword ptr [rsp + {64+i*8}], xmm{i}')
            self.emit('movsd xmm0, xmm14')
            if op == 'fmadd':
                self.emit('movsd xmm1, xmm15', 'movsd xmm2, xmm13')
            self.emit('call ' + ('fma' if op == 'fmadd' else 'floor') + '@PLT', 'movsd xmm14, xmm0')
            for i, register in enumerate(saved):
                self.emit(f'mov {register}, qword ptr [rsp + {i*8}]')
            for i in range(8):
                self.emit(f'movsd xmm{i}, qword ptr [rsp + {64+i*8}]')
            self.emit('mov rsp, qword ptr [rbp + 488]')
            self.fp_store(a[0])
            return
        if op == 'fsqrt':
            self.fp_load('xmm14', a[1])
            self.emit('sqrtsd xmm14, xmm14')
            self.fp_store(a[0])
            return
        if op == 'ret':
            self.emit('jmp qword ptr [rbp + 240]')
            return
        if op in ('bl', 'b'):
            target = a[0]
            if target.startswith('_') and target not in self.symbols:
                self.external(target, op == 'b')
                return
            label = self.symbol(target, path)
            if op == 'bl':
                after = self.unique('return')
                self.emit(f'lea rax, [rip + {after}]', 'mov qword ptr [rbp + 240], rax', f'jmp {label}')
                self.output.append(after + ':')
            else:
                self.emit(f'jmp {label}')
            return
        if op.startswith('b.'):
            self.restore_flags()
            self.emit(f'j{self.conditions[op[2:]]} {self.symbol(a[0], path)}')
            return
        if op in ('cbz', 'cbnz', 'tbz', 'tbnz'):
            bits = 32 if a[0].startswith('w') else 64
            self.load('rax', a[0], bits)
            if op.startswith('tb'):
                bit = self.expr(a[1])
                self.emit(f"bt {('eax' if bits == 32 else 'rax')}, {bit}")
                cond = 'nc' if op == 'tbz' else 'c'
            else:
                self.emit(f"test {('eax' if bits == 32 else 'rax')}, {('eax' if bits == 32 else 'rax')}")
                cond = 'z' if op == 'cbz' else 'nz'
            self.emit(f'j{cond} {self.symbol(a[-1], path)}')
            return
        if op in ('ldr', 'ldrb', 'ldrh', 'str', 'strb', 'strh', 'ldp', 'stp'):
            pair = op in ('ldp', 'stp')
            reg = a[0]
            memory = a[2] if pair else a[1]
            bits = 64 if reg.startswith(('x', 'd')) else 32
            size = 8 if bits == 64 else 4
            if op.endswith('b'):
                size = 1
            elif op.endswith('h'):
                size = 2
            base = self.address(memory)
            for i, r in enumerate(a[:2] if pair else a[:1]):
                at = f'[rax + {i * size}]'
                width = {1: 'byte', 2: 'word', 4: 'dword', 8: 'qword'}[size]
                if op.startswith('ld'):
                    if r.startswith('d'):
                        self.emit(f'movsd xmm14, {width} ptr {at}')
                        self.fp_store(r)
                    else:
                        self.emit(f"{('movzx' if size < 4 else 'mov')} {('r11' if size == 8 else 'r11d')}, {width} ptr {at}")
                        self.store(r, 'r11')
                elif r.startswith('d'):
                    self.fp_load('xmm14', r)
                    self.emit(f'movsd {width} ptr {at}, xmm14')
                else:
                    self.load('r11', r, bits)
                    self.emit(f'mov {width} ptr {at}, ' + {1: 'r11b', 2: 'r11w', 4: 'r11d', 8: 'r11'}[size])
            post = a[3] if pair and len(a) > 3 else a[2] if not pair and len(a) > 2 else None
            if post:
                self.load('rax', base)
                self.load('r11', post)
                self.emit('add rax, r11')
                self.store(base)
            return
        bits = 32 if a and a[0].startswith('w') else 64
        r, s = ('eax', 'r11d') if bits == 32 else ('rax', 'r11')
        if op == 'mov':
            self.load('rax', a[1], bits)
            self.store(a[0])
            return
        if op == 'movk':
            self.load('rax', a[0], bits)
            shift = self.expr(a[2].split()[1]) if len(a) > 2 else 0
            mask = (1 << bits) - 1 ^ 65535 << shift
            self.emit(f'mov r11, {mask}', f'and {r}, {s}', f'mov r11, {(self.expr(a[1]) & 65535) << shift}', f'or {r}, {s}')
            self.store(a[0])
            return
        if op in ('cmp', 'cmn', 'tst'):
            self.load('rax', a[0], bits)
            self.load('r11', a[1], bits)
            if len(a) > 2:
                self.shift('r11', a[2], bits)
            self.emit(f"{ {'cmp': 'cmp', 'cmn': 'add', 'tst': 'test'}[op]} {r}, {s}")
            self.flags()
            if op == 'cmn':
                self.emit('xor qword ptr [rbp + 448], 1')
            elif op == 'tst':
                self.emit('or qword ptr [rbp + 448], 1')
            return
        if op in ('add', 'adds', 'sub', 'subs', 'and', 'orr', 'eor', 'bic', 'mul'):
            self.load('rax', a[1], bits)
            self.load('r11', a[2], bits)
            if len(a) > 3:
                self.shift('r11', a[3], bits)
            if op == 'bic':
                self.emit(f'not {s}')
            operation = {'add': 'add', 'adds': 'add', 'sub': 'sub', 'subs': 'sub', 'and': 'and', 'orr': 'or', 'eor': 'xor', 'bic': 'and', 'mul': 'imul'}[op]
            self.emit(f'{operation} {r}, {s}')
            if op in ('adds', 'subs'):
                self.flags()
                if op == 'adds':
                    self.emit('xor qword ptr [rbp + 448], 1')
            self.store(a[0])
            return
        if op in ('madd', 'msub'):
            self.load('rax', a[1], bits)
            self.load('r11', a[2], bits)
            self.emit(f'imul {r}, {s}')
            if op == 'msub':
                self.emit(f'neg {r}')
            self.load('r11', a[3], bits)
            self.emit(f'add {r}, {s}')
            self.store(a[0])
            return
        if op in ('lsl', 'lsr', 'asr', 'ror'):
            self.load('rax', a[1], bits)
            self.shift('rax', op + ' ' + a[2], bits)
            self.store(a[0])
            return
        if op == 'neg':
            self.load('rax', a[1], bits)
            self.emit(f'neg {r}')
            self.store(a[0])
            return
        if op == 'ubfx':
            self.load('rax', a[1], bits)
            self.emit(f'shr {r}, {self.expr(a[2])}')
            mask = (1 << self.expr(a[3])) - 1
            self.emit(f'mov r11, {mask}', f'and {r}, {s}')
            self.store(a[0])
            return
        if op in ('csel', 'cset', 'cinc', 'cneg'):
            condition = self.conditions[a[-1]]
            yes = self.unique('select')
            done = self.unique('selected')
            self.restore_flags()
            self.emit(f'j{condition} {yes}')
            if op == 'cset':
                self.emit('xor eax, eax')
            else:
                self.load('rax', a[2] if op == 'csel' else a[1], bits)
            self.emit(f'jmp {done}')
            self.output.append(yes + ':')
            if op == 'cset':
                self.emit('mov eax, 1')
            else:
                self.load('rax', a[1], bits)
                if op == 'cinc':
                    self.emit(f'add {r}, 1')
                elif op == 'cneg':
                    self.emit(f'neg {r}')
            self.output.append(done + ':')
            self.store(a[0])
            return
        if op in ('udiv', 'sdiv'):
            self.emit('mov qword ptr [rbp + 464], rdx')
            self.load('rax', a[1], bits)
            self.load('r11', a[2], bits)
            zero = self.unique('div_zero')
            done = self.unique('div_done')
            self.emit(f'test {s}, {s}', f'jz {zero}')
            if op == 'sdiv':
                divide = self.unique('divide')
                self.emit(f'cmp {s}, -1', f'jne {divide}', f'neg {r}', f'jmp {done}')
                self.output.append(divide + ':')
                self.emit('cdq' if bits == 32 else 'cqo', f'idiv {s}')
            else:
                self.emit('xor edx, edx', f'div {s}')
            self.emit(f'jmp {done}')
            self.output.append(zero + ':')
            self.emit('xor eax, eax')
            self.output.append(done + ':')
            self.emit('mov rdx, qword ptr [rbp + 464]')
            self.store(a[0])
            return
        if op == 'rev':
            self.load('rax', a[1], bits)
            self.emit(f'bswap {r}')
            self.store(a[0])
            return
        if op == 'rev16':
            self.load('rax', a[1], bits)
            self.emit('mov qword ptr [rbp + 480], rax', 'mov r11, 18374966859414961920', f'and {r}, {s}', f'shr {r}, 8', 'mov qword ptr [rbp + 496], rax', 'mov rax, qword ptr [rbp + 480]', 'mov r11, 71777214294589695', f'and {r}, {s}', f'shl {r}, 8', f'or {r}, ' + ('dword' if bits == 32 else 'qword') + ' ptr [rbp + 496]')
            self.store(a[0])
            return
        if op == 'fmov':
            if a[0].startswith('d'):
                if a[1].startswith('x'):
                    self.load('rax', a[1])
                    self.emit('movq xmm14, rax')
                else:
                    self.fp_load('xmm14', a[1])
                self.fp_store(a[0])
            else:
                self.fp_load('xmm14', a[1])
                self.emit('movq rax, xmm14')
                self.store(a[0])
            return
        if op in ('fadd', 'fsub', 'fmul', 'fdiv', 'fmin', 'fmax'):
            self.fp_load('xmm14', a[1])
            self.fp_load('xmm15', a[2])
            if op in ('fmin', 'fmax'):
                nan = self.unique('fp_nan')
                normal = self.unique('fp_normal')
                done = self.unique('fp_minmax_done')
                self.emit('ucomisd xmm14, xmm15', f'jp {nan}', f'jne {normal}', 'movq rax, xmm14', 'shl rax, 1', f'jnz {normal}', 'movq rax, xmm14', 'movq r11, xmm15', ('or' if op == 'fmin' else 'and') + ' rax, r11', 'movq xmm14, rax', f'jmp {done}')
                self.output.append(normal + ':')
                self.emit(('minsd' if op == 'fmin' else 'maxsd') + ' xmm14, xmm15', f'jmp {done}')
                self.output.append(nan + ':')
                self.emit('addsd xmm14, xmm15')
                self.output.append(done + ':')
            else:
                self.emit({'fadd':'addsd','fsub':'subsd','fmul':'mulsd','fdiv':'divsd'}[op] + ' xmm14, xmm15')
            self.fp_store(a[0])
            return
        if op in ('fabs', 'fneg'):
            self.fp_load('xmm14', a[1])
            self.emit('movq rax, xmm14', 'mov r11, ' + str(9223372036854775807 if op == 'fabs' else 9223372036854775808), ('and' if op == 'fabs' else 'xor') + ' rax, r11', 'movq xmm14, rax')
            self.fp_store(a[0])
            return
        if op == 'scvtf':
            ib = 32 if a[1].startswith('w') else 64
            self.load('rax', a[1], ib)
            self.emit('cvtsi2sd xmm14, ' + ('eax' if ib == 32 else 'rax'))
            self.fp_store(a[0])
            return
        if op == 'fcvtzs':
            self.fp_load('xmm14', a[1])
            nan = self.unique('convert_nan')
            high = self.unique('convert_high')
            low = self.unique('convert_low')
            done = self.unique('converted')
            self.emit('ucomisd xmm14, xmm14', f'jp {nan}')
            self.fp_load('xmm15', '#' + str(float(1 << bits - 1)))
            self.emit('ucomisd xmm14, xmm15', f'jae {high}')
            self.fp_load('xmm15', '#' + str(-float(1 << bits - 1)))
            self.emit('ucomisd xmm14, xmm15', f'jbe {low}', f'cvttsd2si {r}, xmm14', f'jmp {done}')
            for label, value in ((nan, 0), (high, (1 << bits - 1) - 1), (low, 1 << bits - 1)):
                self.output.append(label + ':')
                self.emit(f'mov {r}, {value}', f'jmp {done}')
            self.output.append(done + ':')
            self.store(a[0])
            return
        if op == 'fcmp':
            self.fp_load('xmm14', a[0])
            self.fp_load('xmm15', a[1])
            nan = self.unique('fcmp_nan')
            less = self.unique('fcmp_less')
            equal = self.unique('fcmp_eq')
            done = self.unique('fcmp_done')
            self.emit('ucomisd xmm14, xmm15', f'jp {nan}', f'jb {less}', f'je {equal}', 'mov qword ptr [rbp + 448], 0', f'jmp {done}')
            for label, value in ((nan, 2048), (less, 129), (equal, 64)):
                self.output.append(label + ':')
                self.emit(f'mov qword ptr [rbp + 448], {value}', f'jmp {done}')
            self.output.append(done + ':')
            return
        raise ValueError(f'unsupported instruction: {op} {a}')

    def generate(self, sources=None):
        for path in sources or sorted((ROOT / 'src/engine').glob('*.s')):
            path = Path(path)
            self.read(path.relative_to(ROOT) if path.is_absolute() else path)
        self.discover()
        self.output = ['// Generated from shared assembly by tools/asm/engine_x86.py. Do not edit.', '.intel_syntax noprefix']
        files = {str(p): i + 1 for i, p in enumerate(sorted({p for p, n, s in self.lines}))}
        for path, i in files.items():
            self.output.append(f'.file {i} "{path}"')
        section = 'text'
        for path, n, line in self.lines:
            try:
                match = re.match('^(\\w+):\\s*(.*)$', line)
                if match:
                    label, rest = match.groups()
                    self.output.append((label if label.isdigit() else self.symbol(label, path)) + ':')
                    line = rest
                    if not line:
                        continue
                if line.startswith('.section'):
                    section = 'data'
                    name = '.bss' if '__bss' in line else '.rodata' if '__cstring' in line else '.data.rel.ro'
                    self.output.append('.section ' + name)
                    continue
                if line == '.text':
                    section = 'text'
                    self.output.append('.text')
                    continue
                if line.startswith('.globl'):
                    continue
                if line.startswith(('.p2align', '.asciz', '.space', '.byte')):
                    self.output.append(line)
                    continue
                if line.startswith('.double '):
                    values = [float(value) for value in args(line[8:])]
                    if any(not math.isfinite(value) for value in values):
                        raise ValueError('non-finite data constant')
                    self.output.append('.double ' + ', '.join(repr(value) for value in values))
                    continue
                if line.startswith('.quad '):
                    values = []
                    for value in args(line[6:]):
                        try:
                            values.append(str(self.expr(value)))
                        except (ValueError, KeyError, SyntaxError):
                            values.append(self.symbol(value, path))
                    self.output.append('.quad ' + ', '.join(values))
                    continue
                if section != 'text':
                    raise ValueError(f'unsupported data {line}')
                self.output.append(f'.loc {files[str(path)]} {n} 0')
                parts = line.split(None, 1)
                self.instruction(parts[0], args(parts[1]) if len(parts) > 1 else [], path)
            except Exception as error:
                raise ValueError(f'{path}:{n}: {line}: {error}') from error
        for name in sorted(self.globals):
            if name in self.functions:
                symbol = name.removeprefix('_')
                ret = self.unique('c_return')
                self.output.extend(['.text', '.p2align 4', f'.globl {symbol}', f'.type {symbol}, @function', symbol + ':'])
                self.emit('push rbp', 'push rbx', 'push r12', 'push r13', 'push r14', 'push r15', 'sub rsp, 520', 'mov rbp, rsp')
                # Never read stack arguments that a short-arity C caller did
                # not allocate. Current core APIs use at most six integers.
                for reg in (6, 7):
                    if self.c_abi_args.get(name, 6) > reg:
                        self.emit(f'mov rax, qword ptr [rbp + {528 + reg * 8}]')
                    else:
                        self.emit('xor eax, eax')
                    self.emit(f'mov qword ptr [rbp + {reg * 8}], rax')
                self.emit(f'lea rax, [rip + {ret}]', 'mov qword ptr [rbp + 240], rax', f'jmp {self.symbols[name]}')
                self.output.append(ret + ':')
                self.emit('mov rax, rdi', 'mov rdx, rsi', 'mov rsp, rbp', 'add rsp, 520', 'pop r15', 'pop r14', 'pop r13', 'pop r12', 'pop rbx', 'pop rbp', 'ret')
                self.output.append(f'.size {symbol}, .-{symbol}')
            else:
                self.output.append('.globl ' + self.symbols[name])
        self.output.append('.section .note.GNU-stack,"",@progbits')
        return '\n'.join(self.output) + '\n'
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--gtk', action='store_true')
    options = parser.parse_args()
    backend = Backend()
    sources = None
    if options.gtk:
        backend.constants['OOGA_GTK'] = 1
        backend.externals = backend.externals | set((ROOT/'src/gtk/externals.txt').read_text().split())
        sources = sorted((ROOT/'src/engine').glob('*.s')) + sorted((ROOT/'src/gtk').glob('*.s')) + sorted((ROOT/'src/mac').glob('svg*.s')) + [ROOT/'src/mac/background-paint.s']
    result = backend.generate(sources)
    options.output.parent.mkdir(parents=True, exist_ok=True)
    options.output.write_text(result)
