import Foundation
import Capacitor
import WebKit
import UIKit

// Custom view controller that enforces portrait orientation
class PortraitViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
}

@objc(ChildWindowPlugin)
public class ChildWindowPlugin: CAPPlugin, WKNavigationDelegate, WKUIDelegate {
    // Rename webView to inAppBrowserWebView to avoid conflict with CAPPlugin's webView property
    private var inAppBrowserWebView: WKWebView?
    private var viewController: PortraitViewController?
    private var swipeGesture: UISwipeGestureRecognizer?
    
    // Track the current navigation state
    private var isInitialLoad: Bool = false
    private var navigationMap: [String: WKNavigation] = [:]
    
    @objc public func open(_ call: CAPPluginCall) {
        guard let urlString = call.getString("url") else {
            call.reject("Must provide a URL")
            return
        }
        
        print("SimpleInAppBrowserPlugin: Opening URL: \(urlString)")
        
        DispatchQueue.main.async {
            // Set the initial load flag
            self.isInitialLoad = true
            
            // Configure WKWebView if needed
            if self.inAppBrowserWebView == nil {
                print("SimpleInAppBrowserPlugin: Creating new WKWebView")
                
                let configuration = WKWebViewConfiguration()
                configuration.preferences.javaScriptEnabled = true
                
                // Use default WKWebView settings without custom user agent
                configuration.processPool = WKProcessPool()
                configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
                
                // Create the WebView with screen bounds
                self.inAppBrowserWebView = WKWebView(frame: UIScreen.main.bounds, configuration: configuration)
                self.inAppBrowserWebView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                self.inAppBrowserWebView?.navigationDelegate = self
                self.inAppBrowserWebView?.uiDelegate = self  // Add UI delegate to handle tel: links
                
                // Disable zoom
                let script = WKUserScript(source: "var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'); document.getElementsByTagName('head')[0].appendChild(meta);", injectionTime: .atDocumentEnd, forMainFrameOnly: true)
                configuration.userContentController.addUserScript(script)
                
                // Disable overscroll and horizontal scrolling
                self.inAppBrowserWebView?.scrollView.bounces = false
                self.inAppBrowserWebView?.scrollView.alwaysBounceHorizontal = false
                self.inAppBrowserWebView?.scrollView.showsHorizontalScrollIndicator = false
                
                // Create portrait-locked view controller if needed
                if self.viewController == nil {
                    self.viewController = PortraitViewController()
                    
                    // Configure WebView to fill the view controller
                    self.viewController?.view = self.inAppBrowserWebView
                    self.viewController?.view.backgroundColor = .white
                    
                    // Set presentation style for full screen on all devices
                    self.viewController?.modalPresentationStyle = .fullScreen
                    
                    // For iPad, ensure we get full screen presentation
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        self.viewController?.modalPresentationStyle = .fullScreen
                        self.viewController?.modalTransitionStyle = .crossDissolve
                    }
                    
                    // Add swipe gesture for closing
                    self.swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(self.handleSwipe(_:)))
                    self.swipeGesture?.direction = .right  // Left-to-right swipe
                    self.inAppBrowserWebView?.addGestureRecognizer(self.swipeGesture!)
                }
                
                // Present the controller if not already presented
                if self.viewController?.presentingViewController == nil {
                    self.bridge?.viewController?.present(self.viewController!, animated: true)
                }
            }
            
            // Load the URL with simple request
            if let url = URL(string: urlString) {
                print("SimpleInAppBrowserPlugin: Loading URL: \(url)")
                
                // Use a simpler request without custom cache policy or timeout
                var request = URLRequest(url: url)
                request.addValue("keep-alive", forHTTPHeaderField: "Connection")
                request.addValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
                
                // Clear the navigation map for new navigation
                self.navigationMap.removeAll()
                
                // Load the URL and track the initial navigation
                if let navigation = self.inAppBrowserWebView?.load(request) {
                    self.navigationMap[urlString] = navigation
                }
            } else {
                print("SimpleInAppBrowserPlugin: Invalid URL: \(urlString)")
                call.reject("Invalid URL")
                return
            }
            
            call.resolve()
        }
    }
    
    @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .right {
            // Close the browser and fire exit event
            self.notifyListeners("exit", data: nil)
            closeInternalBrowser()
        }
    }
    
    private func closeInternalBrowser() {
        DispatchQueue.main.async {
            self.viewController?.dismiss(animated: true)
            self.inAppBrowserWebView = nil
            self.viewController = nil
            self.isInitialLoad = false
            self.navigationMap.removeAll()
        }
    }
    
    @objc public func close(_ call: CAPPluginCall) {
        closeInternalBrowser()
        call.resolve()
    }
    
    // MARK: - WKNavigationDelegate Methods
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        
        let urlString = url.absoluteString
        print("SimpleInAppBrowserPlugin: Navigation request to: \(urlString)")
        
        // Intercept and block telephone links
        if url.scheme == "tel" || url.scheme == "sms" || url.scheme == "mailto" {
            print("SimpleInAppBrowserPlugin: Blocked \(url.scheme) link: \(urlString)")
            
            // Notify JavaScript of the blocked link
            self.notifyListeners("navigate", data: ["url": urlString])
            
            // Block the navigation
            decisionHandler(.cancel)
            return
        }
        
        // Allow the navigation if it's part of the initial load or redirects
        if self.isInitialLoad {
            print("SimpleInAppBrowserPlugin: Allowing navigation as part of initial load/redirects")
            decisionHandler(.allow)
            return
        }
        
        // For any subsequent navigations after the page is fully loaded and ready
        print("SimpleInAppBrowserPlugin: Intercepting navigation after page load")
        self.notifyListeners("navigate", data: ["url": urlString])
        decisionHandler(.cancel)
    }
    
    // MARK: - WKUIDelegate Methods
    
    // This prevents the "Open in new window" dialog
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            if let url = navigationAction.request.url {
                // Instead of opening in a new window, handle it as a normal navigation
                self.notifyListeners("navigate", data: ["url": url.absoluteString])
            }
        }
        return nil
    }
    
    // This prevents JS alerts and other dialogs
    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        // Just complete without showing the alert
        completionHandler()
    }
    
    public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        // Just return false without showing the confirm dialog
        completionHandler(false)
    }
    
    public func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        // Just return nil without showing the prompt
        completionHandler(nil)
    }
    
    // This prevents the Call/Message dialog for tel: links
    public func webView(_ webView: WKWebView, shouldPreviewElement elementInfo: WKPreviewElementInfo) -> Bool {
        let url = elementInfo.linkURL
        
        // If this is a telephone link, don't show preview
        if url?.scheme == "tel" || url?.scheme == "sms" || url?.scheme == "mailto" {
            return false
        }
        
        // Don't allow previews in general
        return false
    }
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Track this navigation if it's part of the initial load sequence
        if self.isInitialLoad, let urlString = webView.url?.absoluteString {
            self.navigationMap[urlString] = navigation
        }
        
        print("SimpleInAppBrowserPlugin: Started loading: \(webView.url?.absoluteString ?? "unknown")")
    }
    
    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        // Track the redirect as part of the initial load sequence if flag is set
        if self.isInitialLoad, let urlString = webView.url?.absoluteString {
            self.navigationMap[urlString] = navigation
        }
        
        print("SimpleInAppBrowserPlugin: Received server redirect: \(webView.url?.absoluteString ?? "unknown")")
    }
    
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("SimpleInAppBrowserPlugin: Page content started loading: \(webView.url?.absoluteString ?? "unknown")")
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("SimpleInAppBrowserPlugin: Finished loading: \(webView.url?.absoluteString ?? "unknown")")
        
        // Check if this is a navigation we're tracking as part of the initial load sequence
        let currentURL = webView.url?.absoluteString ?? ""
        
        // If this navigation was part of our tracked navigations, mark initial load as complete
        if self.navigationMap[currentURL] == navigation {
            print("SimpleInAppBrowserPlugin: Initial load sequence complete")
            self.isInitialLoad = false
            self.navigationMap.removeAll()
        }
        
        self.notifyListeners("loadstop", data: ["url": currentURL])
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // Reset the initial loading state on failure
        self.isInitialLoad = false
        self.navigationMap.removeAll()
        
        let errorCode = (error as NSError).code
        let errorDescription = error.localizedDescription
        let url = webView.url?.absoluteString ?? ""
        
        print("SimpleInAppBrowserPlugin: Loading error: \(errorCode) - \(errorDescription) for URL: \(url)")
        
        self.notifyListeners("loaderror", data: [
            "url": url,
            "errorCode": errorCode,
            "errorDescription": errorDescription
        ])
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Reset the initial loading state on failure
        self.isInitialLoad = false
        self.navigationMap.removeAll()
        
        let errorCode = (error as NSError).code
        let errorDescription = error.localizedDescription
        let url = webView.url?.absoluteString ?? ""
        
        print("SimpleInAppBrowserPlugin: Navigation error: \(errorCode) - \(errorDescription) for URL: \(url)")
        
        self.notifyListeners("loaderror", data: [
            "url": url,
            "errorCode": errorCode,
            "errorDescription": errorDescription
        ])
    }
}