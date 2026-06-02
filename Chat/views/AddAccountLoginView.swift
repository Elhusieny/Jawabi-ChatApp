//
//  AddAccountLoginView.swift
//  Chat
//
//  Created by Ahmed Elhussieny on 14/05/2026.
//


import SwiftUI

struct AddAccountLoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    
    @State private var userName = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    
    private var primaryColor: Color { Color(hex: "#7373d2") }
    private var darkPurpleGradient: [Color] {
        [Color(hex: "#5a5aa8"), Color(hex: "#7373d2")]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#7373d2").opacity(0.15),
                                             Color(hex: "#9d73d2").opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 80, height: 80)
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 34))
                                .foregroundStyle(LinearGradient(
                                    colors: darkPurpleGradient,
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                        }

                        Text("Add Account")
                            .font(.title2).fontWeight(.bold)
                            .foregroundStyle(LinearGradient(
                                colors: darkPurpleGradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            ))

                        Text("Sign in with another account")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Fields
                    VStack(spacing: 16) {
                        // Username
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Username")
                                .font(.subheadline).fontWeight(.medium)
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(LinearGradient(
                                        colors: darkPurpleGradient,
                                        startPoint: .leading, endPoint: .trailing))
                                    .frame(width: 20)
                                TextField("Enter username", text: $userName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.subheadline).fontWeight(.medium)
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(LinearGradient(
                                        colors: darkPurpleGradient,
                                        startPoint: .leading, endPoint: .trailing))
                                    .frame(width: 20)
                                if isPasswordVisible {
                                    TextField("Enter password", text: $password)
                                        .textFieldStyle(PlainTextFieldStyle())
                                } else {
                                    SecureField("Enter password", text: $password)
                                        .textFieldStyle(PlainTextFieldStyle())
                                }
                                Button {
                                    isPasswordVisible.toggle()
                                } label: {
                                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundStyle(LinearGradient(
                                            colors: darkPurpleGradient,
                                            startPoint: .leading, endPoint: .trailing))
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Sign In button
                    VStack(spacing: 12) {
                        if authViewModel.isLoading {
                            ProgressView().scaleEffect(1.2).tint(primaryColor)
                        } else {
                            Button {
                                authViewModel.login(userName: userName, password: password)
                            } label: {
                                HStack {
                                    Text("Sign In")
                                        .font(.headline).fontWeight(.semibold)
                                    Image(systemName: "arrow.right").font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LinearGradient(
                                    colors: darkPurpleGradient,
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .cornerRadius(12)
                                .shadow(color: primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(userName.isEmpty || password.isEmpty)
                            .opacity((userName.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                        }
                    }
                    .padding(.horizontal)

                    // Error
                    if let error = authViewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(LinearGradient(
                            colors: darkPurpleGradient,
                            startPoint: .leading, endPoint: .trailing
                        ))
                }
            }
            // Dismiss when login succeeds — App.swift switches to ChatListView automatically
            .onChange(of: authViewModel.isAuthenticated) { isAuth in
                if isAuth {
                    isPresented = false
                }
            }
        }
        .accentColor(primaryColor)
    }
}