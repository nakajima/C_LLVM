//
//  EmittedValue.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

import C_LLVM

public extension LLVM {
	/// An emitted value is something that can be used in LLVM
	protocol EmittedValue: IRValue, IRValueRef, Emitted {
		associatedtype T: IRType

		var type: T { get }
		var ref: LLVMValueRef { get }

		init(type: T, ref: LLVMValueRef)
	}
}
