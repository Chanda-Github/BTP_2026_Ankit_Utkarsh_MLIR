; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"

define i1 @tm_infer(i1 %0, i1 %1) {
  %3 = xor i1 %0, true
  %4 = xor i1 %1, true
  %5 = and i1 %0, %4
  %6 = zext i1 %5 to i32
  %7 = and i1 %3, %1
  %8 = zext i1 %7 to i32
  %9 = and i1 %0, %1
  %10 = zext i1 %9 to i32
  %11 = and i1 %3, %4
  %12 = zext i1 %11 to i32
  %13 = add i32 %6, %8
  %14 = add i32 %10, %12
  %15 = sub i32 %13, %14
  %16 = icmp sge i32 %15, 0
  ret i1 %16
}

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
