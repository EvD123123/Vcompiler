// This file is part of the materials accompanying the book 
// "The Elements of Computing Systems" by Nisan and Schocken, 
// MIT Press. Book site: www.idc.ac.il/tecs

// New File name: orp2StackTestVME.tst 
// it includes a rewritten tst script for running a rewritten vm file 

// File name: projects/07/StackArithmetic/StackTest/StackTestVME.tst

load orp2StackTest.vm, 
output-file orp2StackTest.out, 
compare-to orp2StackTest.cmp, 
output-list RAM[0]%D2.6.2 RAM[256]%D2.6.2 RAM[257]%D2.6.2
            RAM[258]%D2.6.2 RAM[259]%D2.6.2;

set RAM[0] 256,

repeat 20 { 
  vmstep;
}

output;
