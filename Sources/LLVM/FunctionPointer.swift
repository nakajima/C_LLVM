//
//  FunctionPointer.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/27/24.
//

import C_LLVM

public extension LLVM {
	public protocol FunctionPointer: LLVM.StoredPointer {
		var functionRef: LLVMValueRef { get }
		var capturesRef: LLVMValueRef { get }
	}
}
