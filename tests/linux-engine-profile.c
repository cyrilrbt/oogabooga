// Native Linux clock shim and opt-in shared-engine profiling.
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
extern uint64_t engine_profile_enabled,engine_profile_totals[8],engine_profile_counts[8];
extern uint64_t engine_profile_now(void);
extern void engine_profile_reset(void);
extern void *engine_parse(const char *,size_t);
extern void engine_document_free(void *);
int main(void) {
    uint64_t first=engine_profile_now(),second=engine_profile_now();
    assert(first && second>=first);
    engine_profile_reset();engine_profile_enabled=1;
    const char *html="<style>p{color:blue}</style><p>Native Linux profiling</p>";
    void *document=engine_parse(html,strlen(html));assert(document);
    engine_document_free(document);engine_profile_enabled=0;
    assert(engine_profile_counts[0]==1 && engine_profile_counts[1]>0 && engine_profile_totals[0]>0);
    engine_profile_reset();
    for(unsigned i=0;i<8;i++)assert(!engine_profile_totals[i]&&!engine_profile_counts[i]);
    puts("PASS: Linux monotonic timing, enabled engine profiling and counter reset");
}
