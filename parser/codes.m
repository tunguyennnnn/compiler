
class-Q_wres dw 0
class-Q_w_x dw 0
class-Q_w sw class-Q_w_x(r0),r1
class-Q_w_y dw 0
class-Q_w sw class-Q_w_y(r0),r2

sub r1,r1,r1
addi r1,r1,0
sw for-loop-for-loop-1_variable-i(r0),r1
j startloop0
goloop0


lw r1,for-loop-for-loop-1_variable-i(r0)
addi r1,r1,1
a1 dw 0
sw a1(r0),r1
sub r1,r1,r1
addi r1,r1,a1(r0)
sub r2,r2,r2
addi r2,r2,45
sw for-loop-for-loop-1_variable-d(r2),r1
startloop0
lw r1,for-loop-for-loop-1_variable-i(r0)
clti r2,r1,100
a0 dw 0
sw a0(r0),r2
lw r1,a0(r0)
bnz r1,endloop0

lw r1,for-loop-for-loop-1_variable-i(r0)
cgti r2,r1,10
a2 dw 0
sw a2(r0),r2
lw r1,a2(r0)
bz r1,else0


lw r1,for-loop-for-loop-1_variable-i(r0)
addi r1,r1,1
a3 dw 0
sw a3(r0),r1
sub r1,r1,r1
addi r1,r1,a3(r0)
sub r2,r2,r2
addi r2,r2,45
sw for-loop-for-loop-1_variable-d(r2),r1
j endif0
else0

lw r1,for-loop-for-loop-1_variable-i(r0)
subi r1,r1,1
a4 dw 0
sw a4(r0),r1
lw r1,a4(r0)
sw for-loop-for-loop-1_variable-i,r1
endif0
j startloop0
endloop0

lw r1,method-w_parameter-x(r0)
 sw wres(r0),r1
jr r15
program-program_variable-o    dw 0
program-program_variable-x    res 3
program-program_variable-y    res 108
program-program_variable-z    res 18
subi r1,10,20
a5 dw 0
sw a5(r0),r1
lw r1,a5(r0)
addi r1,3,r1
a6 dw 0
sw a6(r0),r1
sub r1,r1,r1
addi r1,r1,a6(r0)
sub r2,r2,r2
addi r2,r2,6
sw program-program_variable-x(r2),r1
lw r1,1
lw r2,2
lw r15,a7
jr class-Q_w
a7
lw r1,class-Q_wres
addi r1,1,r1
a8 dw 0
sw a8(r0),r1
sub r1,r1,r1
addi r1,r1,a8(r0)
sub r2,r2,r2
addi r2,r2,108
sw program-program_variable-y(r2),r1
