import Foundation
import CloudKit

class CloudKitSyncService {
    static let shared = CloudKitSyncService()
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let recordType = "PomodoroSession"
    
    // Notification para cuando se sincroniza con iCloud
    static let cloudSyncCompletedNotification = Notification.Name("CloudSyncCompleted")
    
    private init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
    }
    
    // Comprobar si el usuario está conectado a iCloud
    func checkiCloudAccountStatus(completion: @escaping (Bool, Error?) -> Void) {
        container.accountStatus { status, error in
            switch status {
            case .available:
                completion(true, nil)
            default:
                completion(false, error)
            }
        }
    }
    
    // Convertir PomodoroSession a CKRecord
    private func createRecord(from session: PomodoroSession) -> CKRecord {
        let recordID = CKRecord.ID(recordName: session.id.uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        
        record["startTime"] = session.startTime as CKRecordValue
        record["endTime"] = session.endTime as CKRecordValue
        record["duration"] = session.duration as CKRecordValue
        record["isCompleted"] = session.isCompleted as CKRecordValue
        
        return record
    }
    
    // Convertir CKRecord a PomodoroSession
    private func createPomodoroSession(from record: CKRecord) -> PomodoroSession? {
        guard let startTime = record["startTime"] as? Date,
              let endTime = record["endTime"] as? Date,
              let duration = record["duration"] as? TimeInterval,
              let isCompleted = record["isCompleted"] as? Bool else {
            return nil
        }
        
        let uuidString = record.recordID.recordName
        guard let id = UUID(uuidString: uuidString) else {
            return nil
        }
        
        return PomodoroSession(
            id: id,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            isCompleted: isCompleted
        )
    }
    
    // Guardar sesiones en iCloud
    func saveSessions(_ sessions: [PomodoroSession], completion: @escaping (Error?) -> Void) {
        let operationQueue = OperationQueue()
        
        for session in sessions {
            let record = createRecord(from: session)
            
            let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            operation.qualityOfService = .userInitiated
            
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .failure(let error):
                    print("Error al guardar en iCloud: \(error.localizedDescription)")
                case .success:
                    break
                }
            }
            
            privateDatabase.add(operation)
        }
        
        operationQueue.addOperation {
            completion(nil)
        }
    }
    
    // Sincronizar todas las sesiones desde iCloud
    func fetchAllSessions(completion: @escaping ([PomodoroSession]?, Error?) -> Void) {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        
        privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { _, result -> CKRecord? in
                    try? result.get()
                }
                
                let sessions = records.compactMap { self.createPomodoroSession(from: $0) }
                
                DispatchQueue.main.async {
                    completion(sessions, nil)
                    NotificationCenter.default.post(name: Self.cloudSyncCompletedNotification, object: nil)
                }
            }
        }
    }
    
    // Eliminar sesiones de iCloud
    func deleteSessions(ids: [UUID], completion: @escaping (Error?) -> Void) {
        let recordIDs = ids.map { CKRecord.ID(recordName: $0.uuidString) }
        
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
        operation.qualityOfService = .userInitiated
        
        operation.modifyRecordsResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    completion(error)
                case .success:
                    completion(nil)
                }
            }
        }
        
        privateDatabase.add(operation)
    }
    
    // Eliminar todas las sesiones de iCloud
    func deleteAllSessions(completion: @escaping (Error?) -> Void) {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        
        privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(error)
                }
            case .success(let (matchResults, _)):
                let recordIDs = matchResults.compactMap { recordID, recordResult -> CKRecord.ID? in
                    do {
                        _ = try recordResult.get()
                        return recordID
                    } catch {
                        return nil
                    }
                }
                
                if recordIDs.isEmpty {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
                operation.qualityOfService = .userInitiated
                
                operation.modifyRecordsResultBlock = { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .failure(let error):
                            completion(error)
                        case .success:
                            completion(nil)
                        }
                    }
                }
                
                self.privateDatabase.add(operation)
            }
        }
    }
} 