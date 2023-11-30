//
//  DashboardTooltipView.swift
//
//
//  Created by Paweł W on 03/04/2023.
//

import SwiftUI

private struct CutoutFramePreferenceKey: PreferenceKey {
    typealias Value = [String: CGRect]

    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

public struct HighlightOverlay<MaskView: View>: ViewModifier {
    @Binding var highlightedView: String?
    @Binding var textFieldMode: TextFieldMode
    var maskView: MaskView
    
    @State private var overlayFrame: CGRect = .zero
    @State private var maskFrames = [String: CGRect]()
    
    public func body(content: Content) -> some View {
        ZStack {
            content
                .onPreferenceChange(CutoutFramePreferenceKey.self) { value in
                    maskFrames = value
                }
                .onChange(of: maskFrames) { _ in
                    overlayFrame = highlightedView.flatMap { maskFrames[$0] } ?? .zero
                }
                .onChange(of: highlightedView) { _ in
                    overlayFrame = highlightedView.flatMap { maskFrames[$0] } ?? .zero
                }
            
            if overlayFrame != .zero {
                ZStack {
                    Color.black.opacity(0.1)
                    ShowInfoView(textFieldMode: $textFieldMode)
                    maskView
                        .frame(width: overlayFrame.size.width,
                               height: overlayFrame.size.height)
                        .position(x: overlayFrame.midX, y: overlayFrame.midY)
                }
                .ignoresSafeArea()
                .coordinateSpace(name: "HighlightOverlayCoordinateSpace")
                .compositingGroup()
                .allowsHitTesting(false)
            }
        }
    }
}

public struct HighlightedItem: ViewModifier {
    var id: String
    
    public func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: CutoutFramePreferenceKey.self,
                                    value: [id: geo.frame(in: .named("HighlightOverlayCoordinateSpace"))])
                }
            )
    }
}

public extension View {
    func tooltipItem(_ id: String) -> some View {
        modifier(HighlightedItem(id: id))
    }
    
    func withHighlightOverlay(highlighting highlightedView: Binding<String?>, textFieldMode: Binding<TextFieldMode>,
                              maskView: some View
    ) -> some View {
        modifier(HighlightOverlay(highlightedView: highlightedView, textFieldMode: textFieldMode,
                                  maskView: maskView
                                 ))
    }
}

// MARK: - Example & preview

struct ExampleView: View {
    // User input states
    @State var username: String = ""
    @State var password: String = ""
    
    // Which text field the user is currently interacting with
    @State var textFieldMode: TextFieldMode = .unowned
    
    @State var showInfo: Bool = false
    @State var isValidUserID: Bool = true
    @State var isValidPassword: Bool = true
    @State private var showLoginAlert: Bool = false
    @State private var isLoggingIn = false
    
    @State var highlightedView: String? = nil
    
    var body: some View {
        VStack {
            VStack(spacing: 40) {
                UserIDCustomTextField(text: Text("UserID"), value: $username, textFieldMode: $textFieldMode, isValidUserID: $isValidUserID, highlightedView: $highlightedView)
                    
                PasswordCustomTextField(text: Text("Password"), value: $password, textFieldMode: $textFieldMode, isValidPassword: $isValidPassword, highlightedView: $highlightedView)
            }
            Spacer()
        }
        .withHighlightOverlay(
            highlighting: $highlightedView,
            textFieldMode: $textFieldMode,
            maskView: item()
        )
        .background(BackgroundImage())
        .onTapGesture { highlightedView = nil }
    }
    
    @ViewBuilder
    func item() -> some View {
        if textFieldMode == .userID {
            HighlightedHeader(text: "UserID")
        } else if textFieldMode == .password {
            HighlightedHeader(text: "Password")
        }
    }
}

struct ExampleView_Preview: PreviewProvider {
    static var previews: some View {
        ExampleView()
    }
}

struct ShowInfoView: View {
    @Binding var textFieldMode: TextFieldMode
    
    var body: some View {
        ZStack(alignment: .center) {
            Rectangle().fill(Color("onyx"))
            contentDisplay
        }
        .opacity(0.9)
        .ignoresSafeArea()
    }
    
    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.black.opacity(0.7))
    }
    
    private var contentDisplay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .frame(height: 100)
                .padding(.horizontal, 20)
            if textFieldMode == .userID {
                userIDText
            } else if textFieldMode == .password {
                passwordText
            }
        }
    }
    
    private var userIDText: some View {
        VStack {
            Text("userIDText")
            Text("userIDText")
            Text("userIDText")
        }
        .foregroundStyle(.white)
        .font(.subheadline)
    }
    
    private var passwordText: some View {
        VStack {
            Text("passwordText")
            Text("passwordText")
            Text("passwordText")
        }
        .foregroundStyle(.white)
        .font(.subheadline)
    }
}


struct UserIDCustomTextField: View {
    var text: Text
    @Binding var value: String
    @Binding var textFieldMode: TextFieldMode
    @Binding var isValidUserID: Bool
    @Binding var highlightedView: String?
    
    // Declared as static so they aren't recreated every time the body renders
    private static let userIDRegex = "^[A-Z]{2}\\d{4}$"
    
    var body: some View {
        VStack {
            header.tooltipItem("userID")
            ZStack(alignment: .trailing) {
                inputField
                    .font(.callout)
                    .foregroundStyle(.white)
                errorIcon
                    .offset(y: -5)
            }.frame(height: 20)
            dividerBasedOnValidation
        }.padding(.horizontal, 30)
    }
    
    private var header: some View {
        HStack {
            text.font(.body).foregroundStyle(.white)
            infoButton // Button to display regex information
            Spacer()
        }
    }
    
    private var infoButton: some View {
        Button {
            textFieldMode = .userID
            highlightedView = "userID"
        } label: {
            Image("ic_info").resizable().frame(width: 20, height: 20).padding(.horizontal, 5)
        }
    }
    
    private var inputField: some View {
        TextField("", text: $value)
            .onChange(of: value, perform: validateUserID)
    }
    
    // Function to validate user ID based on the regex pattern
    private func validateUserID(_ userID: String) {
        // If the userID is empty, consider it valid. Else, use the regex to validate
        isValidUserID = userID.isEmpty ? true : NSPredicate(format: "SELF MATCHES %@", UserIDCustomTextField.userIDRegex).evaluate(with: userID)
    }
    
    private var errorIcon: some View {
        Group {
            if (!isValidUserID) {
                Image("ic_error").resizable().frame(width: 6, height: 32)
            }
        }
    }
    
    private var dividerBasedOnValidation: some View {
        Divider()
            .frame(height: 2)
            .background(dividerColor) // Color based on validation state
            .offset(y: -2)
    }
    
    private var dividerColor: Color {
        // Determine the divider color based on validation state
        return isValidUserID ? Color("50a235_green") : .red
    }
}

struct PasswordCustomTextField: View {
    var text: Text
    @Binding var value: String
    @Binding var textFieldMode: TextFieldMode
    @Binding var isValidPassword: Bool
    @State var showPassword: Bool = false
    @Binding var highlightedView: String?
    
    private static let passwordRegex = "^(?=.*[A-Z].*[A-Z])(?=.*[!@#$&*])(?=.*\\d.*\\d)(?=.*[a-z].*[a-z].*[a-z]).{8}$"
    
    var body: some View {
        VStack {
            header.tooltipItem("password")
            ZStack(alignment: .trailing) {
                inputField
                    .font(.callout)
                    .foregroundStyle(.white)
                errorIcon
                    .offset(y: -5)
            }.frame(height: 20)
            dividerBasedOnValidation
        }.padding(.horizontal, 30)
    }
    
    private var header: some View {
        HStack {
           text.font(.body).foregroundStyle(.white)
            infoButton // Button to display regex information
            Spacer()
            showPasswordButton // Button to toggle password visibility
        }
    }
    
    private var infoButton: some View {
        Button {
            textFieldMode = .password
            highlightedView = "password"
        } label: {
            Image("ic_info").resizable().frame(width: 20, height: 20).padding(.horizontal, 5)
        }
    }
    
    @ViewBuilder
    private var inputField: some View {
        if showPassword {
            TextField("", text: $value)
                .onChange(of: value, perform: validatePassword)
        } else {
            SecureField("", text: $value)
                .onChange(of: value, perform: validatePassword)
        }
    }
    
    // Function to validate user ID based on the regex pattern
    private func validatePassword(_ password: String) {
        // If the password is empty, consider it valid. Else, use the regex to validate
        isValidPassword = password.isEmpty ? true : NSPredicate(format: "SELF MATCHES %@", PasswordCustomTextField.passwordRegex).evaluate(with: password)
    }
    
    private var errorIcon: some View {
        Group {
            if (!isValidPassword) {
                Image("ic_error").resizable().frame(width: 6, height: 32)
            }
        }
    }
    
    private var dividerBasedOnValidation: some View {
        Divider()
            .frame(height: 2)
            .background(dividerColor) // Color based on validation state
            .offset(y: -2)
    }
    
    private var dividerColor: Color {
        // Determine the divider color based on validation state
        return isValidPassword ? Color("50a235_green") : .red
    }
    
    private var showPasswordButton: some View {
        Button {
            showPassword.toggle()
        } label: {
            Text("show").font(.footnote).fontWeight(.semibold)
        }
        .foregroundStyle(Color("forest_green"))
    }
}

// Represents which text field the user is currently interacting with
public enum TextFieldMode {
    case userID, password, unowned
}

struct BackgroundImage: View {
    var body: some View {
        Image("bg_gradient")
            .scaledToFill()
            .edgesIgnoringSafeArea(.all)
    }
}

struct HighlightedHeader: View {
    var text: String
    
    var body: some View {
        HStack {
            Text(text).font(.body).foregroundStyle(.white)
            infoIMG // Button to display regex information
            Spacer()
        }
    }
    
    private var infoIMG: some View {
        Image(.icInfo).resizable().frame(width: 20, height: 20).padding(.horizontal, 5)
    }
}
