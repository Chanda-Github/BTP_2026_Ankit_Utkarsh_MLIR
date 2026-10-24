; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"

define i1 @tm_infer(i1 %0, i1 %1, i1 %2, i1 %3, i1 %4, i1 %5, i1 %6, i1 %7) {
  %9 = xor i1 %0, true
  %10 = xor i1 %1, true
  %11 = xor i1 %2, true
  %12 = xor i1 %3, true
  %13 = xor i1 %4, true
  %14 = xor i1 %5, true
  %15 = xor i1 %6, true
  %16 = xor i1 %7, true
  %17 = and i1 %0, %3
  %18 = zext i1 %17 to i32
  %19 = and i1 %4, %6
  %20 = zext i1 %19 to i32
  %21 = and i1 %1, %5
  %22 = zext i1 %21 to i32
  %23 = and i1 %2, %7
  %24 = zext i1 %23 to i32
  %25 = and i1 %5, %6
  %26 = zext i1 %25 to i32
  %27 = and i1 %9, %12
  %28 = zext i1 %27 to i32
  %29 = and i1 %13, %15
  %30 = zext i1 %29 to i32
  %31 = and i1 %10, %14
  %32 = zext i1 %31 to i32
  %33 = and i1 %11, %16
  %34 = zext i1 %33 to i32
  %35 = and i1 %14, %15
  %36 = zext i1 %35 to i32
  %37 = add i32 %18, %20
  %38 = add i32 %37, %22
  %39 = add i32 %38, %24
  %40 = add i32 %39, %26
  %41 = add i32 %28, %30
  %42 = add i32 %41, %32
  %43 = add i32 %42, %34
  %44 = add i32 %43, %36
  %45 = sub i32 %40, %44
  %46 = icmp sge i32 %45, 0
  ret i1 %46
}

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
