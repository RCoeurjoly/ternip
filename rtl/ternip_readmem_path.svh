`ifndef _TERNIP_READMEM_PATH_SVH
`define _TERNIP_READMEM_PATH_SVH

`define _READMEM_STR(x) `"x`"

`ifdef READMEM_DIR
  `define READMEM_PATH(f) `_READMEM_STR(`READMEM_DIR/f)
`else
  `define READMEM_PATH(f) `"f`"
`endif

`endif
