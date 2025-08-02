//
//  ShareViewController.swift
//  ShareExtension
//
//

import receive_sharing_intent

class ShareViewController: RSIShareViewController {

    override func shouldAutoRedirect() -> Bool {
        return false
    }

     // Use this to change label of Post button
    override func presentationAnimationDidFinish() {
        super.presentationAnimationDidFinish()
        navigationController?.navigationBar.topItem?.rightBarButtonItem?.title = "Send"
    }

}
