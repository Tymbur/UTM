//
// Copyright © 2020 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

@available(iOS 14, macOS 11, *)
struct AlertMessage: Identifiable {
    var message: String
    public var id: String {
        message
    }
    
    init(_ message: String) {
        self.message = message
    }
}

@available(iOS 14, macOS 11, *)
class UTMData: ObservableObject {
    
    @Published var showSettingsModal: Bool
    @Published var alertMessage: AlertMessage?
    @Published var busy: Bool
    @Published var selectedVM: UTMVirtualMachine?
    @Published private(set) var virtualMachines: [UTMVirtualMachine] {
        didSet {
            let defaults = UserDefaults.standard
            var paths = [String]()
            virtualMachines.forEach({ vm in
                if let path = vm.path {
                    paths.append(path.lastPathComponent)
                }
            })
            defaults.set(paths, forKey: "VMList")
        }
    }
    
    #if os(macOS)
    var vmWindows: [UTMVirtualMachine: VMDisplayWindowController] = [:]
    #endif
    
    var fileManager: FileManager {
        FileManager.default
    }
    
    var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    var tempURL: URL {
        fileManager.temporaryDirectory
    }
    
    init() {
        let defaults = UserDefaults.standard
        self.showSettingsModal = false
        self.busy = false
        self.virtualMachines = []
        if let files = defaults.array(forKey: "VMList") as? [String] {
            for file in files {
                let url = documentsURL.appendingPathComponent(file, isDirectory: true)
                if let vm = UTMVirtualMachine(url: url) {
                    self.virtualMachines.append(vm)
                }
            }
        }
        self.selectedVM = nil
    }
    
    func refresh() {
        // remove stale vm
        var list = virtualMachines.filter { (vm: UTMVirtualMachine) in vm.path != nil && fileManager.fileExists(atPath: vm.path!.path) }
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
            let newFiles = files.filter { newFile in
                !virtualMachines.contains { existingVM in
                    existingVM.path == newFile
                }
            }
            for file in newFiles {
                guard try file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false else {
                    continue
                }
                guard UTMVirtualMachine.isVirtualMachine(url: file) else {
                    continue
                }
                let vm = UTMVirtualMachine(url: file)
                if vm != nil {
                    list.insert(vm!, at: 0)
                } else {
                    logger.error("Failed to create object for \(file)")
                }
            }
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        if virtualMachines != list {
            DispatchQueue.main.async {
                //self.objectWillChange.send()
                self.virtualMachines = list
            }
        }
    }
    
    // MARK: - New name
    
    func newDefaultVMName(base: String = "Virtual Machine") -> String {
        let nameForId = { (i: Int) in i <= 1 ? base : "\(base) \(i)" }
        for i in 1..<1000 {
            let name = nameForId(i)
            let file = UTMVirtualMachine.virtualMachinePath(name, inParentURL: documentsURL)
            if !fileManager.fileExists(atPath: file.path) {
                return name
            }
        }
        return ProcessInfo.processInfo.globallyUniqueString
    }
    
    func newDefaultDriveName(type: UTMDiskImageType, forConfig: UTMConfiguration) -> String {
        let nameForId = { (i: Int) in "\(type.description)-\(i).qcow2" }
        for i in 0..<1000 {
            let name = nameForId(i)
            let file = forConfig.imagesPath.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: file.path) {
                return name
            }
        }
        return UUID().uuidString
    }
    
    // MARK: - VM functions
    
    func save(vm: UTMVirtualMachine) throws {
        do {
            let oldPath = vm.path
            try vm.saveUTM()
            let newPath = vm.path
            // change the saved path
            if oldPath?.path != newPath?.path {
                guard let oldName = oldPath?.lastPathComponent else {
                    return
                }
                guard let newName = newPath?.lastPathComponent else {
                    return
                }
                let defaults = UserDefaults.standard
                if var files = defaults.array(forKey: "VMList") as? [String] {
                    if let index = files.firstIndex(of: oldName) {
                        files[index] = newName
                        defaults.set(files, forKey: "VMList")
                    }
                }
            }
        } catch {
            // refresh the VM object as it is now stale
            do {
                try discardChanges(forVM: vm)
            } catch {
                // if we can't discard changes, recreate the VM from scratch
                recreate(vm: vm)
            }
            throw error
        }
    }
    
    func discardChanges(forVM vm: UTMVirtualMachine) throws {
        try vm.reloadConfiguration()
    }
    
    func create(config: UTMConfiguration) throws {
        let vm = UTMVirtualMachine(configuration: config, withDestinationURL: documentsURL)
        try save(vm: vm)
        DispatchQueue.main.async {
            self.virtualMachines.append(vm)
        }
    }
    
    func move(fromOffsets: IndexSet, toOffset: Int) {
        DispatchQueue.main.async {
            self.virtualMachines.move(fromOffsets: fromOffsets, toOffset: toOffset)
        }
    }
    
    func delete(vm: UTMVirtualMachine) throws {
        try fileManager.removeItem(at: vm.path!)
        
        DispatchQueue.main.async {
            if let index = self.virtualMachines.firstIndex(of: vm) {
                self.virtualMachines.remove(at: index)
            }
            if vm == self.selectedVM {
                self.selectedVM = nil
            }
        }
    }
    
    func clone(vm: UTMVirtualMachine) throws {
        let newName = newDefaultVMName(base: vm.configuration.name)
        let newPath = UTMVirtualMachine.virtualMachinePath(newName, inParentURL: documentsURL)
        
        try fileManager.copyItem(at: vm.path!, to: newPath)
        guard let newVM = UTMVirtualMachine(url: newPath) else {
            throw NSLocalizedString("Failed to clone VM.", comment: "UTMData")
        }
        
        DispatchQueue.main.async {
            self.virtualMachines.append(newVM)
        }
    }
    
    func edit(vm: UTMVirtualMachine) {
        DispatchQueue.main.async {
            self.selectedVM = vm
            self.showSettingsModal = true
        }
    }
    
    func computeSize(forVM: UTMVirtualMachine) -> Int64 {
        guard let path = forVM.path else {
            logger.error("invalid path for vm")
            return 0
        }
        guard let enumerator = fileManager.enumerator(at: path, includingPropertiesForKeys: [.totalFileSizeKey]) else {
            logger.error("failed to create enumerator for \(path)")
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.totalFileSizeKey]), let size = resourceValues.totalFileSize else {
                continue
            }
            total += Int64(size)
        }
        return total
    }
    
    // MARK: - Export debug log
    
    func exportDebugLog(forConfig: UTMConfiguration) throws -> [URL] {
        guard let path = forConfig.existingPath else {
            throw NSLocalizedString("No log found!", comment: "UTMData")
        }
        let srcLogPath = path.appendingPathComponent(UTMConfiguration.debugLogName())
        let dstLogPath = tempURL.appendingPathComponent(UTMConfiguration.debugLogName())
        
        if fileManager.fileExists(atPath: dstLogPath.path) {
            try fileManager.removeItem(at: dstLogPath)
        }
        try fileManager.copyItem(at: srcLogPath, to: dstLogPath)
        
        return [dstLogPath]
    }
    
    func copyUTM(at: URL, to: URL, move: Bool = false) throws {
        if move {
            try fileManager.moveItem(at: at, to: to)
        } else {
            try fileManager.copyItem(at: at, to: to)
        }
        guard let vm = UTMVirtualMachine(url: to) else {
            throw NSLocalizedString("Failed to parse imported VM.", comment: "UTMData")
        }
        DispatchQueue.main.async {
            self.virtualMachines.append(vm)
            self.selectedVM = vm
        }
    }
    
    func importUTM(url: URL) throws {
        logger.info("importing: \(url)")
        let fileBasePath = url.deletingLastPathComponent()
        let fileName = url.lastPathComponent
        let dest = documentsURL.appendingPathComponent(fileName, isDirectory: true)
        if dest.resolvingSymlinksInPath().path == url.resolvingSymlinksInPath().path {
            if let vm = virtualMachines.first(where: { vm -> Bool in
                guard let vmPath = vm.path else {
                    return false
                }
                return vmPath.lastPathComponent == fileName
            }) {
                logger.info("found existing vm!")
                DispatchQueue.main.async {
                    self.selectedVM = vm
                }
            } else {
                logger.error("cannot find existing vm")
            }
        } else if (fileBasePath.resolvingSymlinksInPath().path == documentsURL.appendingPathComponent("Inbox", isDirectory: true).path) {
            logger.info("moving from Inbox")
            try copyUTM(at: url, to: dest, move: true)
        } else {
            logger.info("copying to Documents")
            try copyUTM(at: url, to: dest)
        }
    }
    
    // MARK: - Disk drive functions
    
    func importDrive(_ drive: URL, forConfig: UTMConfiguration, copy: Bool = false) throws {
        let name = drive.lastPathComponent
        let imagesPath = forConfig.imagesPath
        let dstPath = imagesPath.appendingPathComponent(name)
        if !fileManager.fileExists(atPath: imagesPath.path) {
            try fileManager.createDirectory(at: imagesPath, withIntermediateDirectories: false, attributes: nil)
        }
        if copy {
            try fileManager.copyItem(at: drive, to: dstPath)
        } else {
            try fileManager.moveItem(at: drive, to: dstPath)
        }
        DispatchQueue.main.async {
            forConfig.newDrive(name, type: .CD, interface: UTMConfiguration.defaultDriveInterface())
        }
    }
    
    func createDrive(_ drive: VMDriveImage, forConfig: UTMConfiguration) throws {
        var name: String = ""
        if !drive.removable {
            guard drive.size > 0 else {
                throw NSLocalizedString("Invalid drive size.", comment: "UTMData")
            }
            name = newDefaultDriveName(type: drive.imageType, forConfig: forConfig)
            let imagesPath = forConfig.imagesPath
            let dstPath = imagesPath.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: imagesPath.path) {
                try fileManager.createDirectory(at: imagesPath, withIntermediateDirectories: false, attributes: nil)
            }
            
            // create drive
            // TODO: implement custom qcow2 creation
            let sema = DispatchSemaphore(value: 0)
            let imgCreate = UTMQemuImg()
            var success = false
            var msg = ""
            imgCreate.op = .create
            imgCreate.outputPath = dstPath
            imgCreate.sizeMiB = drive.size
            imgCreate.compressed = true
            #if os(macOS)
            imgCreate.setupXpc()
            #endif
            imgCreate.start { (_success, _msg) in
                success = _success
                msg = _msg
                sema.signal()
            }
            sema.wait()
            if !success {
                throw msg
            }
        }
        
        DispatchQueue.main.async {
            let interface = drive.interface ?? UTMConfiguration.defaultDriveInterface()
            if drive.removable {
                forConfig.newRemovableDrive(drive.imageType, interface: interface)
            } else {
                forConfig.newDrive(name, type: drive.imageType, interface: interface)
            }
        }
    }
    
    func removeDrive(at: Int, forConfig: UTMConfiguration) throws {
        let path = forConfig.driveImagePath(for: at)!
        
        if fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(atPath: path)
        }
        
        DispatchQueue.main.async {
            forConfig.removeDrive(at: at)
        }
    }
    
    // MARK: - Helper functions
    
    private func recreate(vm: UTMVirtualMachine) {
        guard let path = vm.path else {
            logger.error("Attempting to refresh unsaved VM \(vm.configuration.name)")
            return
        }
        guard let newVM = UTMVirtualMachine(url: path) else {
            logger.debug("Cannot create new object for \(path.path)")
            return
        }
        DispatchQueue.main.async {
            //self.objectWillChange.send()
            if let index = self.virtualMachines.firstIndex(of: vm) {
                self.virtualMachines.remove(at: index)
                self.virtualMachines.insert(newVM, at: index)
            } else {
                self.virtualMachines.insert(newVM, at: 0)
            }
            if self.selectedVM == vm {
                self.selectedVM = newVM
            }
        }
    }
    
    func busyWork(_ work: @escaping () throws -> Void) {
        DispatchQueue.main.async {
            self.busy = true
        }
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                DispatchQueue.main.async {
                    self.busy = false
                }
            }
            do {
                try work()
            } catch {
                logger.error("\(error)")
                DispatchQueue.main.async {
                    self.alertMessage = AlertMessage(error.localizedDescription)
                }
            }
        }
    }
}
