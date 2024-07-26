//
//  EmittedValue.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

import C_LLVM

public extension LLVM {
    protocol EmittedValue: IRValue, IRValueRef, Emitted {
        associatedtype T: IRType

        var type: T { get }
        var ref: LLVMValueRef { get }

        init(type: T, ref: LLVMValueRef)
    }
}
