import Foundation
import CoreData

#if os(macOS)
import PDFKit
#endif

extension PaperworkEntity {
    /// Convenience method to create a new PaperworkEntity
    static func create(
        in context: NSManagedObjectContext,
        name: String,
        fileName: String,
        fileData: Data,
        pageCount: Int16 = 0,
        contact: ContactEntity? = nil
    ) -> PaperworkEntity {
        let entity = PaperworkEntity(context: context)
        entity.id = UUID()
        entity.name = name
        entity.fileName = fileName
        entity.fileData = fileData
        entity.pageCount = pageCount
        entity.dateAdded = Date()
        entity.dateModified = Date()
        entity.currentPage = 0
        entity.isSigned = false
        entity.annotationsData = nil
        entity.contact = contact
        return entity
    }

    #if os(macOS)
    /// Get a PDFDocument from stored file data
    var pdfDocument: PDFDocument? {
        guard let data = fileData else { return nil }
        return PDFDocument(data: data)
    }
    #endif
}
