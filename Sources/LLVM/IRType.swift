//
//  LLVMType.swift
//
//
//  Created by Pat Nakajima on 7/16/24.
//
import C_LLVM

public extension LLVM {
    protocol IRType<V>: IR {
        associatedtype V: IRValue
        func typeRef(in context: Context) -> LLVMTypeRef
    }
}

extension LLVMOpcode: LLVM.IR {
    public func asLLVM<T>() -> T {
        self as! T
    }
}
