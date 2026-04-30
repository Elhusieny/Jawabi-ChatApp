

import Foundation
import SwiftUI

struct SettingsView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("userEmail") private var userEmail = ""
    @AppStorage("userName") private var userName = ""
    @State private var showingLogoutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingLoginSheet = false
    
    var body: some View {
        NavigationView {
            List {
                if isLoggedIn {
                    // Account Section (when logged in)
                    Section {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(userName.isEmpty ? "User" : userName)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Text(userEmail)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Account Information")
                    }
                    
                    // Account Actions
                    Section {
                        Button(action: {
                            // Edit profile action
                        }) {
                            Label("Edit Profile", systemImage: "pencil")
                        }
                        
                        Button(action: {
                            // Change password action
                        }) {
                            Label("Change Password", systemImage: "lock")
                        }
                        
                        Button(action: {
                            // Notification settings
                        }) {
                            Label("Notification Settings", systemImage: "bell")
                        }
                        
                        Button(action: {
                            showingLogoutAlert = true
                        }) {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                        }
                    } header: {
                        Text("Account Management")
                    }
                    
                    // Danger Zone
                    Section {
                        Button(action: {
                            showingDeleteAccountAlert = true
                        }) {
                            Label("Delete Account", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    } header: {
                        Text("Danger Zone")
                    } footer: {
                        Text("Once you delete your account, there is no going back. Please be certain.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                } else {
                    // Not logged in state
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 80))
                                .foregroundColor(.gray)
                                .padding(.top, 20)
                            
                            Text("Not Signed In")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Sign in to manage your account and access all features")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button(action: {
                                showingLoginSheet = true
                            }) {
                                Text("Sign In / Sign Up")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                
                // App Settings Section (always visible)
                Section {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                    
                    NavigationLink(destination: LanguageSettingsView()) {
                        Label("Language", systemImage: "globe")
                    }
                    
                    NavigationLink(destination: PrivacySettingsView()) {
                        Label("Privacy", systemImage: "hand.raised")
                    }
                    
                    NavigationLink(destination: AboutView()) {
                        Label("About", systemImage: "info.circle")
                    }
                } header: {
                    Text("App Settings")
                }
                
                // Version Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                } footer: {
                    Text("© 2024 Your App Name. All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Settings")
            .alert("Log Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    logout()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
            .sheet(isPresented: $showingLoginSheet) {
                LoginView()
            }
        }
    }
    
    private func logout() {
        // Perform logout actions
        isLoggedIn = false
        userEmail = ""
        userName = ""
    }
    
    private func deleteAccount() {
        // Perform account deletion
        isLoggedIn = false
        userEmail = ""
        userName = ""
    }
}



// MARK: - Placeholder Views

struct AppearanceSettingsView: View {
    @AppStorage("appTheme") private var appTheme = "system"
    
    var body: some View {
        List {
            Section {
                Picker("Theme", selection: $appTheme) {
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("System").tag("system")
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle("Appearance")
    }
}

struct LanguageSettingsView: View {
    @AppStorage("appLanguage") private var appLanguage = "en"
    
    var body: some View {
        List {
            Section {
                Picker("Language", selection: $appLanguage) {
                    Text("English").tag("en")
                    Text("Spanish").tag("es")
                    Text("French").tag("fr")
                    Text("German").tag("de")
                    Text("Japanese").tag("ja")
                    Text("Chinese").tag("zh")
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle("Language")
    }
}

struct PrivacySettingsView: View {
    @AppStorage("analyticsEnabled") private var analyticsEnabled = true
    @AppStorage("locationEnabled") private var locationEnabled = false
    
    var body: some View {
        List {
            Section {
                Toggle("Share Analytics", isOn: $analyticsEnabled)
                Toggle("Location Services", isOn: $locationEnabled)
            } footer: {
                Text("We respect your privacy. You can control how your data is used.")
            }
            
            Section {
                NavigationLink("Privacy Policy") {
                    Text("Privacy Policy Content")
                        .padding()
                }
                
                NavigationLink("Terms of Service") {
                    Text("Terms of Service Content")
                        .padding()
                }
            }
        }
        .navigationTitle("Privacy")
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "app.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Your App Name")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .listRowBackground(Color.clear)
            }
            
            Section {
                Link("Visit Website", destination: URL(string: "https://yourapp.com")!)
                Link("Contact Support", destination: URL(string: "mailto:support@yourapp.com")!)
                Link("Follow on Twitter", destination: URL(string: "https://twitter.com/yourapp")!)
            }
            
            Section {
                Text("© 2024 Your Company. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("About")
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
