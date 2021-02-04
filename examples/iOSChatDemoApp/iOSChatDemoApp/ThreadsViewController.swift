//
//  ViewController.swift
//  iOSChatDemoApp
//
//  Created by Gloria Li on 2021-02-01.
//

import UIKit
import AzureCommunicationChat
import AzureCore
import AzureCommunication
import AzureCommunicationSignaling

class ThreadsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet var threadsTableView: UITableView!
    @IBAction func createNewThreadButtonTapped(){
        createNewThread()
    }
    
    func createNewThread()
    {
        let participant = ChatParticipant(
            id: currentUser!.id,
            displayName: currentUser?.name,

            shareHistoryTime: Iso8601Date(string: "2020-10-30T10:50:50Z")!
        )
        let request = CreateChatThreadRequest(
            topic: "Lunch Thread",
            participants: [
                participant
            ]
        )
        chatClient?.create(thread: request) { result, _ in
            switch result {
            case let .success(response):
                print(response)
                
                guard let thread = response.chatThread else {
                    print("Failed to extract chatThread from response")
                    return
                }
                do {
                    chatThreadClient = try chatClient?.createClient(forThread: thread.id)
                    chatThreads.append(thread)
                    DispatchQueue.main.async(execute: {
                        self.threadsTableView.reloadData()
                    })
                } catch _ {
                    print("Failed to initialize ChatThreadClient")
                }
            case let .failure(error):
                print("Unexpected failure happened in Create Thread")
                print("\(error)")
            }
        }
    }
    
    func onStart (skypeToken: String)
    {
        let communicationUserCredential: CommunicationTokenCredential
        do {
            communicationUserCredential = try CommunicationTokenCredential(token:skypeToken)
        } catch {
            fatalError(error.localizedDescription)
        }
        chatThreads.removeAll()
        chatClient = getClient(credential:communicationUserCredential)
        
        chatClient?.listThreads { result, _ in
            switch result {
            case let .success(threads):
                for thread in threads.items ?? []
                {
                    if thread.deletedOn == nil
                    {
                        chatThreads.append(ChatThread(id: thread.id, topic: thread.topic, createdOn: Iso8601Date(), createdBy: "", deletedOn: thread.deletedOn))
                    }
                }
                DispatchQueue.main.async(execute: {
                    self.threadsTableView.reloadData()
                })
            case .failure:
                print("Unexpected failure happened in list chat threads")
            }
        }
    
        chatClient?.startRealTimeNotifications()
        chatClient?.on(event: "chatMessageReceived", listener:{
                (response, eventId)
                in
            let response = response as! ChatMessageReceivedEvent
            chatMessages.append(ChatMessage(id: "", type: ChatMessageType.text, sequenceId: "", version: "", content:ChatMessageContent(message:response.content, topic: nil, participants: nil, initiator: nil), senderDisplayName: response.senderDisplayName , createdOn: Iso8601Date(), senderId: "", deletedOn: nil, editedOn: nil))

            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "newMessage")))
            }
        )
        chatClient?.on(event: "chatThreadCreated", listener:{
            (response, eventId)
            in
            let response = response as! ChatThreadCreatedEvent
        })
        
        chatClient?.on(event: "participantsAdded", listener:{
            (response, eventId)
            in
            let response = response as! ParticipantsAddedEvent
        })
        
        chatClient?.on(event: "participantsRemoved", listener:{
            (response, eventId)
            in
            let response = response as! ParticipantsRemovedEvent
        })
        
        chatClient?.on(event: "typingIndicatorReceived", listener:{
            (response, eventId)
            in
            let response = response as! TypingIndicatorReceivedEvent
        })
        chatClient?.on(event: "readReceiptReceived", listener:{
            (response, eventId)
            in
            let response = response as! ReadReceiptReceivedEvent
        })
        chatClient?.on(event: "chatMessageEdited", listener:{
            (response, eventId)
            in
            let response = response as! ChatMessageEditedEvent
        })
        chatClient?.on(event: "chatMessageDeleted", listener:{
            (response, eventId)
            in
            let response = response as! ChatMessageDeletedEvent
        })
        chatClient?.on(event: "chatThreadPropertiesUpdated", listener:{
            (response, eventId)
            in
            let response = response as! ChatThreadPropertiesUpdatedEvent
        })
        chatClient?.on(event: "chatThreadDeleted", listener:{
            (response, eventId)
            in
            let response = response as! ChatThreadDeletedEvent
        })
    }
    
    func getClient(credential: CommunicationTokenCredential? = nil) -> ChatClient {
        let scope = Constants.endpoint
        do {
            let options = AzureCommunicationChatClientOptions(logger: ClientLoggers.none)
            return try ChatClient(endpoint: scope, credential: credential!, withOptions: options)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chatThreads.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = chatThreads[indexPath.row].topic
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        threadsTableView.deselectRow(at: indexPath, animated: true)
        
        do {
            chatThreadClient = try chatClient?.createClient(forThread: chatThreads[indexPath.row].id)
        } catch _ {
            print("Failed to initialize ChatThreadClient")
        }
        
        chatMessages.removeAll()
        getMessages()

        performSegue(withIdentifier: "SegueToChatViewController", sender: self)
    }
    
    func getMessages()
    {
        chatThreadClient?.listMessages(completionHandler: { result, _ in
            switch result {
            case let .success(messages):
                for message in messages.items?.reversed() ?? []
                {
                    if message.type == ChatMessageType.text && message.deletedOn == nil
                    {
                        chatMessages.append(message)
                    }
                }
                NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "newMessage")))
            case .failure:
                print("Unexpected failure happened in list chat threads")
            }
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        threadsTableView.delegate = self
        threadsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        threadsTableView.dataSource = self
        if let unwrappedCurrentUser = currentUser
        {
            onStart(skypeToken: unwrappedCurrentUser.token)
        }
        else
        {
            print("Unexpected failure happened initializing current user")
        }
    }
}
