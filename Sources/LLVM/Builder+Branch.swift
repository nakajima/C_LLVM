//
//  Builder+Branch.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

import C_LLVM

public extension LLVM.Builder {
    func branch(
        condition: () -> any LLVM.EmittedValue,
        consequence: () -> any LLVM.EmittedValue,
        alternative: (() -> (any LLVM.EmittedValue))? = nil
    ) -> any LLVM.EmittedValue {
        // Get the current position we're at so we can go back there after the function is defined
        let originalFunction: LLVMValueRef? = if let originalBlock = LLVMGetInsertBlock(builder) {
            LLVMGetBasicBlockParent(originalBlock)
        } else {
            nil // This means we're in main
        }

        let condition = LLVMBuildICmp(
            builder,
            LLVMIntEQ,
            condition().ref,
            LLVM.IntType.i1.constant(1).valueRef(in: context),
            ""
        )

        let thenBlock = LLVMAppendBasicBlockInContext(
            context.ref,
            originalFunction,
            "then"
        )

        let elseBlock = LLVMAppendBasicBlockInContext(
            context.ref,
            originalFunction,
            "else"
        )

        let mergeBlock = LLVMAppendBasicBlockInContext(
            context.ref,
            originalFunction,
            "merge"
        )

        LLVMBuildCondBr(
            builder,
            condition,
            thenBlock,
            elseBlock
        )

        LLVMPositionBuilderAtEnd(builder, thenBlock)
        let consequenceEmitted = consequence()
        LLVMBuildBr(builder, mergeBlock)

        var values: [LLVMValueRef?] = [consequenceEmitted.ref]
        var blocks: [LLVMBasicBlockRef?] = [thenBlock]

        LLVMPositionBuilderAtEnd(builder, elseBlock)
        let alternativeEmitted: (any LLVM.EmittedValue)? = if let alternative {
            {
                let alternativeResult = alternative()

                values.append(alternativeResult.ref)
                blocks.append(elseBlock)

                LLVMBuildBr(builder, mergeBlock)

                return alternativeResult
            }()
        } else {
            nil
        }

        LLVMPositionBuilderAtEnd(builder, mergeBlock)
        let phiRetType = consequenceEmitted.type.typeRef(in: context)
        let phiNode = LLVMBuildPhi(builder, phiRetType, "merge")!

        let count = values.count
        values.withUnsafeMutableBufferPointer { valuesPtr in
            blocks.withUnsafeMutableBufferPointer { blocksPtr in
                LLVMAddIncoming(
                    phiNode,
                    valuesPtr.baseAddress,
                    blocksPtr.baseAddress,
                    UInt32(count)
                )
            }
        }

        switch consequenceEmitted.type {
        case let value as LLVM.IntType:
            return LLVM.PhiNode(type: value, ref: phiNode)
        case let value as LLVM.FunctionType:
            return LLVM.PhiNode(type: value, ref: phiNode)
        default:
            fatalError()
        }
    }
}
