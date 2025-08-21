//
//  BugReportView.swift
//  osimono
//
//  Created by Apple on 2025/04/28.
//
import SwiftUI
import Firebase
import FirebaseAuth

struct BugReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isDescriptionFocused: Bool
    @State private var bugDescription: String = ""
    @State private var contactEmail: String = ""
    @State private var includeScreenshot: Bool = false
    @State private var includeDeviceInfo: Bool = true
    @State private var isSubmitting: Bool = false
    @State private var showingSubmitSuccess: Bool = false
    @State private var showingDiscardAlert: Bool = false
    @ObservedObject var viewModel = RomanceAppViewModel()
    
    // Get current user email if available
    private var userEmail: String {
        Auth.auth().currentUser?.email ?? ""
    }
    
    // Accent color with dark mode support
    private var accentColor: Color {
        colorScheme == .dark ? .pink.opacity(0.9) : .pink
    }
    
    // Gradient for button
    private var buttonGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [.pink, .pink.opacity(0.8)]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Form content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Description field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("バグ報告・ご意見の内容")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(accentColor)
                            
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $bugDescription)
                                    .focused($isDescriptionFocused)
                                    .frame(minHeight: 150)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isDescriptionFocused ? accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                
                                if bugDescription.isEmpty && !isDescriptionFocused {
                                    Text("改善点や追加を希望する機能などございましたら\nお気軽にご連絡ください\n可能な限りご要望にお応えいたします")
                                        .foregroundColor(.gray.opacity(0.8))
                                        .padding(.top, 20)
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        
                        // Submit button
                        Button(action: {
                            generateHapticFeedback()
                            submitBugReport()
                        }) {
                            HStack {
                                Spacer()
                                
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.horizontal, 8)
                                } else {
                                    Text("送信する")
                                        .fontWeight(.bold)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 16)
                            .background(
                                bugDescription.isEmpty
                                ? AnyShapeStyle(Color.gray.opacity(0.5))
                                : AnyShapeStyle(buttonGradient)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: bugDescription.isEmpty ? Color.clear : accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(bugDescription.isEmpty || isSubmitting)
                        .padding(.top, 16)
                        
                        // Privacy note
                        Text("提供された情報は問題解決のためだけに使用され、第三者に共有されることはありません。")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.top, 16)
                    }
                    .padding()
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("お問い合せ")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(accentColor)
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            if !bugDescription.isEmpty {
                                showingDiscardAlert = true
                            } else {
                                dismiss()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(accentColor)
                        }
                    }
                }
            }
            .alert(isPresented: $showingSubmitSuccess) {
                Alert(
                    title: Text("送信されました"),
                    message: Text("お問合せいただきありがとうございます。"),
                    dismissButton: .default(Text("OK")) {
                        dismiss()
                    }
                )
            }
            .alert("変更を破棄しますか？", isPresented: $showingDiscardAlert) {
                Button("破棄", role: .destructive) { dismiss() }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("入力した内容は保存されません。")
            }
            .onAppear {
                // Pre-populate email if user is signed in
                if contactEmail.isEmpty && !userEmail.isEmpty {
                    contactEmail = userEmail
                }
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    // Submit bug report
    func submitBugReport() {
        isSubmitting = true
        
        viewModel.updateContact(userId: viewModel.currentUserID!, newContact: bugDescription){ success in
            self.bugDescription = ""
        }
        
        // Simulate submission process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSubmitting = false
            showingSubmitSuccess = true
        }
    }
    
    // Generate haptic feedback
    func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // Hide keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// Preview
#Preview {
    BugReportView()
}
