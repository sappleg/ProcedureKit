//
//  ProcedureKit
//
//  Copyright © 2015-2018 ProcedureKit. All rights reserved.
//

import XCTest
import ProcedureKit
import TestingProcedureKit
@testable import ProcedureKitCoreData

open class ProcedureKitCoreDataTestCase: ProcedureKitTestCase {

    typealias Insert = InsertManagedObjectsProcedure<TestEntityItem, TestEntity>
    typealias Filter = FilteredExistingItemsProcedure<TestEntityItem, TestEntity>

    final class TestInsert: GroupProcedure, InputProcedure, OutputProcedure {
        typealias Item = TestEntityItem

        var input: Pending<NSPersistentContainer> = .pending
        var output: Pending<ProcedureResult<[TestEntity]>> = .pending

        let shouldSave: Bool
        let download: ResultProcedure<[Item]>
        var managedObjectContext: NSManagedObjectContext!

        init(items: [Item], andSave shouldSave: Bool = true) {
            self.shouldSave = shouldSave
            self.download = ResultProcedure { items }
            super.init(operations: [download])
        }

        override func execute() {
            guard let container = input.value else {
                finish(withError: ProcedureKitError.requirementNotSatisfied())
                return
            }

            managedObjectContext = container.newBackgroundContext()

            let insert = Insert(into: managedObjectContext, andSave: shouldSave) { (_, item, testEntity) in
                testEntity.identifier = item.identity
                testEntity.name = item.name
            }

            insert.injectResult(from: download)

            insert.addWillFinishBlockObserver { [unowned self] (procedure, errors, _) in
                self.output = procedure.output
            }

            add(child: insert)

            super.execute()
        }
    }

    final class TestFilter: GroupProcedure, InputProcedure, OutputProcedure {
        typealias Item = TestEntityItem

        var input: Pending<NSPersistentContainer> = .pending
        var output: Pending<ProcedureResult<[Item]>> = .pending

        let download: ResultProcedure<[Item]>

        init(items: [Item]) {
            self.download = ResultProcedure { items }
            super.init(operations: [download])
        }

        override func execute() {
            guard let container = input.value else {
                finish(withError: ProcedureKitError.requirementNotSatisfied())
                return
            }

            let filter = Filter(from: container.newBackgroundContext())
                .injectResult(from: download)

            filter.addWillFinishBlockObserver { [unowned self] (procedure, errors, _) in
                self.output = procedure.output
            }

            add(child: filter)

            super.execute()
        }
    }

    var managedObjectModel: NSManagedObjectModel {
        let bundle = Bundle(for: type(of: self))
        guard let model = NSManagedObjectModel.mergedModel(from: [bundle]) else {
            fatalError("Unable to load TestDataModel.xcdatamodeld from test bundle.")
        }
        return model
    }

    var persistentStoreDescriptions: [NSPersistentStoreDescription] {
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        return [description]
    }

    var items: [TestEntityItem]!

    var coreDataStack: LoadCoreDataProcedure!

    var fetchTestEntities: TransformProcedure<NSPersistentContainer, [TestEntity]>!

    open override func setUp() {
        super.setUp()

        items = [
            TestEntityItem(identity: "a-1", name: "Foo"),
            TestEntityItem(identity: "b-2", name: "Bar"),
            TestEntityItem(identity: "c-3", name: "Bat")
        ]


        coreDataStack = LoadCoreDataProcedure(
            name: "TestDataModel",
            managedObjectModel: managedObjectModel,
            persistentStoreDescriptions: persistentStoreDescriptions
        )

        coreDataStack.addWillFinishBlockObserver  { (procedure, errors, _) in
            guard errors.isEmpty, let container = procedure.output.success else { return }
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            container.viewContext.undoManager = nil
            container.viewContext.shouldDeleteInaccessibleFaults = true
            container.viewContext.automaticallyMergesChangesFromParent = true
        }

        fetchTestEntities = TransformProcedure<NSPersistentContainer, [TestEntity]> { (container) in
            return try container.viewContext.fetch(TestEntity.fetchRequest())
        }.injectResult(from: coreDataStack)

    }

    open override func tearDown() {
        items = nil
        coreDataStack = nil
        fetchTestEntities = nil
        super.tearDown()
    }
}

internal struct TestEntityItem: Identifiable {
    let identity: String
    let name: String
}

extension TestEntity: Identifiable {
    public var identity: String {
        return identifier! // Beware: it is not optional in core data, doesn't guarantee this.
    }
}

class TestSuiteRuns: XCTestCase {

    func test__suite_runs() {
        XCTAssertTrue(true)
    }
}