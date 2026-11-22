"""Build-tool checks; instruction behavior is tested by tests/engine-abi.*."""
import unittest
from pathlib import Path
from engine_x86 import Backend, uncomment, ROOT
import tempfile

class BackendTests(unittest.TestCase):
    def test_deterministic_output(self):
        sources=[Path('tests/engine-abi.s')]
        self.assertEqual(Backend().generate(sources),Backend().generate(sources))

    def test_unknown_instruction_is_rejected(self):
        backend=Backend()
        with self.assertRaisesRegex(ValueError,'unsupported instruction'):
            backend.instruction('svc',['#0'],Path('tests/engine-abi.s'))

    def test_constant_evaluator_rejects_executable_code(self):
        with self.assertRaises(ValueError):
            Backend().expr("__import__('os').getcwd()")

    def test_quoted_urls_are_not_comments(self):
        self.assertEqual(uncomment('.asciz "https://example.test/" // comment'),
                         '.asciz "https://example.test/"')

    def test_unknown_constant_operators_are_rejected(self):
        with self.assertRaises(ValueError):
            Backend().expr('not 1')

    def test_generated_code_has_native_entry_points(self):
        assembly=Backend().generate([Path('tests/engine-abi.s')])
        self.assertIn('.intel_syntax noprefix',assembly)
        self.assertIn('.type backend_eight, @function',assembly)
        self.assertIn('call strlen@PLT',assembly)
        self.assertIn('.note.GNU-stack',assembly)
        eight = assembly.split('backend_eight:')[-1].split('.size backend_eight,')[0]
        word = assembly.split('backend_word:')[-1].split('.size backend_word,')[0]
        self.assertIn('[rbp + 576]', eight)
        self.assertNotIn('[rbp + 576]', word)

    def test_same_filename_in_distinct_modules_keeps_local_symbols_private(self):
        (ROOT/'build').mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT/'build') as directory:
            paths=[]
            for module in ('one','two'):
                path=Path(directory)/module/'probe.s';path.parent.mkdir()
                path.write_text(f'.text\n.globl _{module}\n_{module}:\nLsame:\n    ret\n')
                paths.append(path)
            assembly=Backend().generate(paths)
            locals=[line for line in assembly.splitlines() if line.endswith('_Lsame:')]
            self.assertEqual(len(locals),2)
            self.assertNotEqual(*locals)

    def test_native_callback_addresses_reject_unknown_abis(self):
        with self.assertRaises(ValueError):
            Backend().instruction('ooga_callback',['x0','_unknown_abi'],Path('probe.s'))

    def test_conditional_macros_only_define_the_active_platform(self):
        (ROOT/'build').mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT/'build') as directory:
            path=Path(directory)/'conditional.s'
            path.write_text('.ifdef PLATFORM\n.macro ACTIVE\n mov x0, #7\n.endm\n.else\n.macro ACTIVE\n mov x0, #99\n.endm\n.endif\n.text\n.globl _platform\n_platform:\n ACTIVE\n ret\n')
            backend=Backend();backend.constants['PLATFORM']=1
            assembly=backend.generate([path])
            self.assertIn('mov rax, 7',assembly)
            self.assertNotIn('mov rax, 99',assembly)

if __name__=='__main__':
    unittest.main()
