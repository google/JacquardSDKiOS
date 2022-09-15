// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import CoreData

/// CoreDataStackManager provides methods to interact with persistent store, create & save context.
final class CoreDataStackManager {

  private enum Constants {
    static let coreDataModelName = "Jacquard_SDK"
  }

  // MARK: - Core Data stack

  private lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(name: Constants.coreDataModelName)
    container.loadPersistentStores(completionHandler: { (storeDescription, error) in
      if let error = error as NSError? {
        assertionFailure("Coredata load error \(error), \(error.userInfo)")
      }
    })
    return container
  }()

  var context: NSManagedObjectContext {
    return persistentContainer.viewContext
  }

  func save() {
    if context.hasChanges {
      do {
        // Save Managed Object Context
        try context.save()
      } catch {
        assertionFailure("Unable to save managed object context error: \(error)")
      }
    }
  }

  func create(entity: String) -> NSManagedObject {
    guard let entity = NSEntityDescription.entity(forEntityName: entity, in: context) else {
      assertionFailure("Could not create coredata entity")
      return NSManagedObject()
    }
    return NSManagedObject(entity: entity, insertInto: context)
  }
}
