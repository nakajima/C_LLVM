//
//  BinaryOperation.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

import C_LLVM

public extension LLVM {
	enum BinaryOperator: UInt32 {
		case add

		var toLLVM: LLVMOpcode {
			switch self {
			case .add:
				LLVMAdd
			}
		}
	}

	struct BinaryOperation<V: EmittedValue>: IRValue {
		public typealias T = V.T

		public let lhs: V
		public let rhs: V
		public let op: BinaryOperator

		public var type: V.T

		public init(op: BinaryOperator, lhs: V, rhs: V) {
			self.op = op
			self.lhs = lhs
			self.rhs = rhs
			type = lhs.type
		}
	}
}
