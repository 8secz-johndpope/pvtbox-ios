/**
*  
*  Pvtbox. Fast and secure file transfer & sync directly across your devices. 
*  Copyright © 2020  Pb Private Cloud Solutions Ltd. 
*  
*  Licensed under the Apache License, Version 2.0 (the "License");
*  you may not use this file except in compliance with the License.
*  You may obtain a copy of the License at
*     http://www.apache.org/licenses/LICENSE-2.0
*  
*  Unless required by applicable law or agreed to in writing, software
*  distributed under the License is distributed on an "AS IS" BASIS,
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*  See the License for the specific language governing permissions and
*  limitations under the License.
*  
**/

import Foundation

struct Strings {
    static let licenseStrings = [
        Const.unknownLicense: "Unknown license",
        Const.freeLicense: "Free license",
        Const.trialLicense: "Free 14-days trial",
        Const.proLicense: "Pro account",
        Const.businessLicense: "Business account",
        Const.businessAdminLicense: "Business (Admin) account",
    ]

    static let licenseIsFree = "Pvtbox license is Free..."
    static let upgradeLicense = "Please upgrade license"
    static let syncDisabled = "Syncing across devices disabled"
    
    static let cameraFolderDeleted = "Camera folder was deleted"
    static let setAddPhotosInSettings = "You can switch \"Automatically add photos and videos from camera\" in Settings to continue syncing your camera with other devices"
    
    static let notImplemented = "Not implemented yet"
    static let notAvailableForFreeLicense = "Not available for free license"
    static let actionCancelled = "Action cancelled"
    
    static let areYouSure = "Are you sure?"
    
    static let allFiles = "All Files"
    
    static let dir = "dir"
    static let folder = "folder"
    static let file = "file"
    static let files = "files"
    
    static let ok = "OK"
    static let cancel = "CANCEL"
    static let yes = "YES"
    
    static let loggedOutByRemoteAction = "Logged out by remote action"
    
    static let protectYourPrivacyWithPasscodeTitle = "Protect your privacy with passcode"
    static let protectYourPrivacyWithPasscodeMessage = "Tap 'SET PASSCODE' to create it now or You can create passcode later via settings"
    static let setPasscode = "Set passcode"
    static let noThanks = "No, thanks"
    
    // Download statuses
    static let processingStatus = "Processing..."
    static let waitingNodesStatus = "Waiting nodes..."
    static let startingDownloadStatus = "Starting download..."
    static let waitingOtherDownloadsStatus = "Waiting other downloads..."
    static let downloadingStatus = "Downloading..."
    static let finishingDownloadStatus = "Finishing download..."
    static let waitingInitialSyncStatus = "Waiting initial sync..."
    
    // LoginVC
    static let signIn = "SIGN IN"
    static let signUp = "SIGN UP FOR FREE"
    static let pleaseWait = "PLEASE WAIT..."
    static let emailEmpty = "Email can't be empty"
    static let hostEmpty = "Self-hosted server address can't be empty"
    static let emailWrong = "Wrong email format"
    static let passwordEmpty = "Password can't be empty"
    static let passwordShort = "Password length must be at least 6 character"
    static let passwordBig = "Password can't contail more than 32 symbols"
    static let passwordIncorrect = "Incorrect password characters"
    static let passwordNotEq = "Password not equal with confirmation"
    static let confirmRules = "Please confirm Rules and Privacy Policy."
    static let rules = "Terms And Conditions"
    static let privacyPolicy = "Privacy Policy"
    static let ipBlockedTemplate = "Your ip is locked now, you can repeat operation in %d sec"
    static let ipUnlocked = "Your ip was unlocked, you can repeat operation now"
    static let selfHostedUser = "I'm self-hosted user"
    static let regularUser = "I'm regular user"
    
    // More
    static let faq = "Frequently Asked Questions"
    
    // SupportVC
    static let send = "SEND"
    static let sending = "SENDING..."
    static let messageEmpty = "Message can't be empty"
    static let messageSent = "Message to support successfully sent"
    static let messageSendError = "Failed to send message right now, please try again later"
    static let pleaseSelectSubject = "Please select subject"
    
    // Get Link
    static let createLink = "CREATE LINK"
    static let createLinkFirstly = "You should create link firstly"
    static let linkCopied = "The link was copied to clipboard"
    static let creatingLink = "Creating link..."
    static let createdLink = "Link created successfully"
    static let cancellingShare = "Cancelling share..."
    static let cancelledShare = "Share cancelled successfully"
    static let enterPassword = "Enter password"
    static let updatingShare = "Updating share..."
    static let updatedShare = "Updated share"
    
    // Collaborations
    static let owner = "Owner"
    static let canView = "Can view"
    static let canEdit = "Can edit"
    static let addingCollabColleague = "Adding colleague to collaboration..."
    static let addedCollabColleague = "Added colleague to collaboration successfully"
    static let removingCollabColleague = "Removing colleague from collaboration..."
    static let removedCollabColleague = "Removed colleague from collaboration successfully"
    static let quitCollaboration = "Quit collaboration"
    static let removeUser = "Remove user"
    static let cantRemovePermissionFromSelf = "Can't remove permission from yourself.\nYou can quit collaboration instead"
    static let cantRemovePermissionFromColleague = "Can't remove view permission from colleague.\nYou can remove user instead"
    static let quittingCollaboration = "Quitting collaboration..."
    static let quittedCollaboration = "Quit collaboration successfully"
    static let updatingCollabColleaguePermission = "Updating colleague permission..."
    static let updatedCollabColleaguePermission = "Updated colleague permission successfully"
    static let onlyRootFoldersCanBeCollaborated = "Only root folders can be collaborated"
    static let deleteCollaborationAlertMessage = "Collaboration will be cancelled, collaboration folder will be deleted from all colleagues Pvtbox secured sync folders on all nodes."
    static let quitCollaborationAlertMessage = "Collaboration folder will be deleted from Pvtbox secured sync folders on all your nodes."
    static let colleagueRemoveAlertMessage = "Colleague %@ will be removed from collaboration. Collaboration folder will be deleted from colleague Pvtbox secured sync folders on all nodes."
    
    
    // Files
    static let peerConnected = "peer connected"
    static let peersConnected = "peers connected"
    static let connectNodesToSync = "Connect more devices to sync"
    static let rename = "Rename"
    static let newFolder = "New folder"
    static let insertLink = "Insert share link"
    static let renamePlaceholder = "Please, enter new name"
    static let newFolderPlaceholder = "Please, enter name of new folder"
    static let actionDisabled = "Action disabled while another action performing"
    static let deleteQuestion = "Do you want to delete"
    static let objects = "objects"
    static let fromAllYourDevices = "from all your devices"
    static let nothingSelected = "Nothing selected, operations disabled"
    static let noAppropriateOfflineState = "No appropriate offline state to change"
    static let selected = "Selected"
    static let cant = "Can't"
    static let toItself = "to itself"
    static let copy = "copy"
    static let move = "move"
    static let recentlyAdded = "Recently added"
    static let recentlyModified = "Recently modified"
    static let added = "Added"
    static let modified = "Modified"
    static let ago = "ago"
    static let offline = "offline"
    static let nameEmpty = "Name can't be empty"
    static let linkEmpty = "Please insert share link"
    static let linkInvalid = "Link invalid"
    static let wrongPassword = "Wrong password"
    static let lockedAfterTooManyIncorrectAttempts = "Locked after too many incorrect attempts"
    static let errorProcessingLink = "Error processing link"
    static let folderAlreadyExists = "Folder with this name already exist"
    static let fileAlreadyExists = "File with this name already exist"
    static let moveToSameLocation = "Can't move to same location"
    static let fileNotUpToDate = "The current file is not up-to-date.\n\nDo you want to download a new version?"
    static let open = "Open"
    static let download = "Download"
    static let cantPreview = "File can't be previewed"
    static let fileDeletedFromDeviceCamera = "File was deleted from device.\nCreate offline copy to preview"
    static let downloadsPaused = "Downloads paused"
    static let downloadsResumed = "Downloads resumed"
    
    // Devices
    static let synced = "Synced"
    static let loggedOut = "Logged Out"
    static let wiped = "Wiped"
    static let powerOff = "Power Off"
    static let paused = "Paused"
    static let indexing = "Indexing"
    static let connecting = "Connecting"
    static let syncing = "Syncing"
    static let currentDevices = "Current Devices"
    static let network = "Network"
    static let done = "done"
    static let connectingToServers = "Connecting to servers..."
    static let syncingLocal = "Syncing local"
    static let importingCamera = "Importing camera..."
    static let importedCamera = "Successfully imported camera"
    static let importCameraCancelled = "Camera import cancelled"
    static let processingOperations = "Processing operations..."
    static let processingShare = "Processing share..."
    static let syncingRemote = "Syncing remote"
    static let eventsTotal = "events total..."
    static let fetchingChanges = "Fetching changes..."
    static let downloading = "Downloading"
    static let filesTotal = "files total"
    static let secondLetter = "s"
    static let removingNode = "Removing node..."
    static let removedNode = "Successfully removed node"
    static let sendingRemoteAction = "Sending remote action..."
    static let remoteActionSent = "Remote action sent successfully"
    static let deviceRemoveAlertMessage = "\"%@\" node will be removed from the list of devices. Files will not be wiped."
    static let deviceWipeAlertMessage = "All files from \"%@\" node's Pvtbox secured sync folder will be wiped."
    static let logout = "Log out"
    static let logoutInProgress = "Log out in progress..."
    static let wipe = "Log out & wipe"
    static let wipeInProgress = "Wipe in progress..."
    
    // Notifications
    static let acceptingInvitation = "Accepting invitation..."
    static let acceptedInvitation = "Invitation accepted successfully"
    
    // Settings
    static let keepLocalFiles = "Keep local files on device?"
    static let keep = "KEEP"
    static let clear = "CLEAR ALL"
    static let settings = "SETTINGS"
    static let cameraSyncAlertTitle = "All nodes offline"
    static let cameraSyncAlertMessage = "Your gallery will be synced when there is at least one online node"
    static let cameraAuthorizationDeniedAlertTitle = "Pvtbox needs access to your photo library"
    static let cameraAuthorizationDeniedAlertMessage = "To give access, tap 'SETTINGS' and turn on Photo Library Access"
    static let cameraSyncDisabledByPermission = "Camera synchronization disabled cause photo library access denied"
    
    // OperationService
    static let of = "of"
    static let total = "total"
    static let creatingFolder = "Creating folder..."
    static let createFolderError = "Create folder error"
    static let folderCreated = "Folder created successfully"
    static let renamingFolder = "Renaming folder..."
    static let renamingFile = "Renaming file..."
    static let renameError = "Rename error"
    static let renamed = "Renamed successfully"
    static let deletingFile = "Deleting file..."
    static let deletingFolder = "Deleting folder..."
    static let deletingObjects = "Deleting objects..."
    static let deleteError = "Delete error"
    static let deleted = "Deleted successfully"
    static let movingFile = "Moving file..."
    static let movingFolder = "Moving folder..."
    static let movingObjects = "Moving objects..."
    static let moveError = "Move error"
    static let moved = "Moved successfully"
    static let copyingFile = "Copying file..."
    static let copyingFolder = "Copying folder..."
    static let copyingObjects = "Copying objects..."
    static let copyError = "Copy error"
    static let copied = "Copied successfully"
    static let addingObjectsToOffline = "Adding objects to offline..."
    static let addingFolderToOffline = "Adding folder to offline..."
    static let addingFileToOffline = "Adding file to offline..."
    static let addedToOffline = "Added to offline successfully"
    static let removingObjectsFromOffline = "Removing objects from offline..."
    static let removingFolderFromOffline = "Removing folder from offline..."
    static let removingFileFromOffline = "Removing file from offline..."
    static let removedFromOffline = "Removed from offline successfully"
    static let addingPhoto = "Adding a photo to device's secured sync folder..."
    static let addingVideoFile = "Adding a video file to device's secured sync folder..."
    static let adding = "Adding to device's secured sync folder..."
    static let addingObjects = "Adding objects to device's secured sync folder..."
    static let addError = "Add error"
    static let addedSuccessfully = "Added successfully"
    static let operationError = "Operation error"
    static let networkError = "Network error"
    static let cancellingDownload = "Cancelling download..."
    static let cancellingDownloads = "Cancelling downloads..."
    static let cancelledDownload = "Download cancelled successfully"
    static let cancelledDownloads = "Downloads cancelled successfully"
    
    // UploadsDownloader
    static let downloadingFile = "Downloading file"
    static let downloadCancelled = "Download cancelled"
    static let addingFile = "Adding a file to device's secured sync folder"
    static let downloadedAndAddedFile = "Downloaded and Added file successfully"
    
    // ShareSignalServerService
    static let startingShareDownload = "Starting share download..."
    static let shareDownloaded = "Share downloaded successfully"
    static let shareUnavailable = "Share unavailable.\nPerhaps access was closed or expired."
    static let shareDownloadCancelled = "Share download cancelled"
    static let downloadingSharedFile = "Downloading shared file"
    static let downloadingShare = "Downloading share"
    
    // IntroVC
    static let next = "NEXT"
    static let gotIt = "GOT IT"
}
