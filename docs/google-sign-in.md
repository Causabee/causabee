# Google sign-in

With Google sign-in, a Gmail or Google Workspace address needs no app password. The person clicks
**Sign in with Google** in the setup (Matterbee → Set Up Matterbee … → Mail), signs in on Google's
own page, and Matterbee opens Gmail with a token.

The button only shows once Matterbee has a Google client ID. Making one is a one-time job in
Google's console, and only the owner of the Google account can do it.

## Making the client ID (about 15 minutes)

1. Open [console.cloud.google.com](https://console.cloud.google.com) and make a new project,
   for example "Matterbee".
2. **APIs & Services → Library:** find **Gmail API** and click **Enable**. Without it, Gmail's
   permission cannot be chosen in step 4.
3. **Google Auth Platform → Branding:** app name "Matterbee", and your address as the support
   and contact address.
   **Audience:** choose **External**, and leave it in **Testing**. Under **Test users**, add every
   address that will sign in, your own first. Up to 100.
4. **Data access → Add or remove scopes:** add `https://mail.google.com/`. Google marks it as
   "restricted". That is expected: it is the only permission Gmail's IMAP accepts.
5. **Clients → Create client:** application type **iOS**, bundle ID `de.chille.matterbee`.
   Google shows a client ID ending in `.apps.googleusercontent.com`. There is no secret to keep.
6. Put the client ID into `GoogleSignIn.clientID` in
   `Sources/MatterCore/Google/GoogleSignIn.swift` and build again. The client ID is not a secret:
   every app that signs in with Google carries its own.

## What to know

- **Testing mode signs out after 7 days.** While the app is in Testing, Google stops the sign-in
  a week later. Matterbee then says so, and signing in again in the setup takes a minute. This
  only ends when Google has verified the app.
- **Verification** is needed before people outside the 100 test users can sign in. For a
  restricted permission, Google may ask for a yearly security assessment by an outside company.
  Check Google's current rules before planning a public release.
- **What Matterbee does with it:** the token only goes to Google, to Gmail's IMAP server and to
  Google's token address. The refresh token is kept in the Keychain as "Matterbee — Google
  sign-in for …". Matterbee still only reads, and writes nothing but a draft when asked.
- **Signing out:** "Use another account" in the setup removes the token from this Mac. To remove
  Matterbee's access completely, also remove it at
  [myaccount.google.com/connections](https://myaccount.google.com/connections).
- **The app password still works.** Accounts logged in with an app password stay as they are;
  an address signed in with Google is used first.
- **The command line** (`matter-spike`) uses a Google sign-in made in the app, but cannot make
  one itself.
