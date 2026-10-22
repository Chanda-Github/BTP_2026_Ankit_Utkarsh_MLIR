module {
  llvm.func @tm_infer(%arg0: i1, %arg1: i1, %arg2: i1, %arg3: i1, %arg4: i1, %arg5: i1, %arg6: i1, %arg7: i1) -> i1 {
    %0 = llvm.mlir.constant(true) : i1
    %1 = llvm.mlir.constant(0 : i32) : i32
    %2 = llvm.xor %arg0, %0  : i1
    %3 = llvm.xor %arg1, %0  : i1
    %4 = llvm.xor %arg2, %0  : i1
    %5 = llvm.xor %arg3, %0  : i1
    %6 = llvm.xor %arg4, %0  : i1
    %7 = llvm.xor %arg5, %0  : i1
    %8 = llvm.xor %arg6, %0  : i1
    %9 = llvm.xor %arg7, %0  : i1
    %10 = llvm.and %arg0, %arg3  : i1
    %11 = llvm.zext %10 : i1 to i32
    %12 = llvm.and %arg4, %arg6  : i1
    %13 = llvm.zext %12 : i1 to i32
    %14 = llvm.and %arg1, %arg5  : i1
    %15 = llvm.zext %14 : i1 to i32
    %16 = llvm.and %arg2, %arg7  : i1
    %17 = llvm.zext %16 : i1 to i32
    %18 = llvm.and %arg5, %arg6  : i1
    %19 = llvm.zext %18 : i1 to i32
    %20 = llvm.and %2, %5  : i1
    %21 = llvm.zext %20 : i1 to i32
    %22 = llvm.and %6, %8  : i1
    %23 = llvm.zext %22 : i1 to i32
    %24 = llvm.and %3, %7  : i1
    %25 = llvm.zext %24 : i1 to i32
    %26 = llvm.and %4, %9  : i1
    %27 = llvm.zext %26 : i1 to i32
    %28 = llvm.and %7, %8  : i1
    %29 = llvm.zext %28 : i1 to i32
    %30 = llvm.add %11, %13  : i32
    %31 = llvm.add %30, %15  : i32
    %32 = llvm.add %31, %17  : i32
    %33 = llvm.add %32, %19  : i32
    %34 = llvm.add %21, %23  : i32
    %35 = llvm.add %34, %25  : i32
    %36 = llvm.add %35, %27  : i32
    %37 = llvm.add %36, %29  : i32
    %38 = llvm.sub %33, %37  : i32
    %39 = llvm.icmp "sge" %38, %1 : i32
    llvm.return %39 : i1
  }
}

