//
//  EmittedValue.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

import C_LLVM

public extension LLVM {
	protocol EmittedValue: IRValue, IRValueRef, Emitted {
		associatedtype V: IRValue

		var type: V.T { get }
		var value: V { get }
		var ref: LLVMValueRef { get }

		init(type: V.T, value: V, ref: LLVMValueRef)
	}
}
