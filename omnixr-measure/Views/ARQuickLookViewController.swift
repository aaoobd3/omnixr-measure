//
//  ARQuickLookViewController.swift
//  omnixr-measure
//
//  Created by AI Assistant on 07/28/2025.
//

import SwiftUI
import QuickLook
import UIKit

struct ARQuickLookViewController: UIViewControllerRepresentable {
    
    let usdzURL: URL
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> QLPreviewControllerWrapper {
        let controller = QLPreviewControllerWrapper()
        controller.previewController.dataSource = context.coordinator
        controller.previewController.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewControllerWrapper, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDelegate, QLPreviewControllerDataSource {
        let parent: ARQuickLookViewController
        
        init(parent: ARQuickLookViewController) {
            self.parent = parent
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.usdzURL as QLPreviewItem
        }
        
        func previewControllerWillDismiss(_ controller: QLPreviewController) {
            parent.isPresented = false
        }
    }
}

extension ARQuickLookViewController {
    
    class QLPreviewControllerWrapper: UIViewController {
        let previewController = QLPreviewController()
        var quickLookIsPresented = false
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            
            if !quickLookIsPresented {
                present(previewController, animated: false)
                quickLookIsPresented = true
            }
        }
    }
} 