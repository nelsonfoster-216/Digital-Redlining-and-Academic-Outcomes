#!/bin/bash
awk '
BEGIN { found=0; skip=0; }
/Performance Index/ { 
  if (found == 1) { 
    skip=1; 
  } else { 
    found=1; 
    print; 
  }
  next;
}
{ 
  if (skip == 1) { 
    skip=0; 
  } else { 
    print; 
  }
}
' digital_redlining_eda_consolidated.html > fixed.html
mv fixed.html digital_redlining_eda_consolidated.html 