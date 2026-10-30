# gpt-oss:20b on Apple M5, 16 GB

- macOS 26.6.2, Ollama 0.40.13
- iogpu.wired_limit_mb: 0
- recommendedMaxWorkingSetSize: 11.84 GiB

## OLLAMA_CONTEXT_LENGTH=32768

```
msg="inference compute" id=0 filter_id=0 library=Metal compute=0.0 name=MTL0 description="Apple M5" libdirs=ollama driver=0.0 pci_id="" type=iGPU total="11.8 GiB" available="11.8 GiB"
msg="vram-based default context" total_vram="11.8 GiB" default_num_ctx=4096
```

| run | load | prompt tok | prefill tok/s | gen tok | decode tok/s |
|---|---|---|---|---|---|
| cold | 41.3 s | 78 | 2.5 | 64 | 0.3 |
| warm | 0.1 s | 76 | 2.7 | 64 | 0.4 |

```
NAME           ID              SIZE     PROCESSOR          CONTEXT    RUNNER      UNTIL              
gpt-oss:20b    f38aa0c53da5    14 GB    23%/77% CPU/GPU    32768      llamacpp    4 minutes from now    
llama_kv_cache:       MTL0 KV buffer size =   768.00 MiB
llama_kv_cache: size =  768.00 MiB ( 32768 cells,  12 layers,  1/1 seqs), K (f16):  384.00 MiB, V (f16):  384.00 MiB
llama_kv_cache:       MTL0 KV buffer size =    18.00 MiB
llama_kv_cache: size =   18.00 MiB (   768 cells,  12 layers,  1/1 seqs), K (f16):    9.00 MiB, V (f16):    9.00 MiB
System-wide memory free percentage: 3%
vm.swapusage: total = 13312.00M  used = 12468.31M  free = 843.69M  (encrypted)
```

