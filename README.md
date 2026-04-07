A PowerShell Windows Forms GUI tool that creates self-signed SSL/code-signing certificates, exports them as PFX files with password protection, and signs EXE/DLL/MSI files using Windows SDK's signtool.exe. Features a dark-themed interface with certificate configuration, password strength indicator, SDK auto-detection, and timestamping support.

Here's the step-by-step infographic. Here's a quick summary of the 6 steps:
1) Fill Certificate Identity — enter a Common Name (CN) like MyApp, optional organization, and any DNS SANs.
2) Configure PFX Export — check the export box, choose a save path, and set a strong password (confirmed).
3) Click "Create Certificate" — the cert is generated in the Windows store and the .pfx file is saved.
4) Verify signtool SDK — scroll to the Code Signing section and confirm the green "SDK OK" banner appears.
5) Add EXE/DLL files — click "Add..." to browse or paste file paths (one per line).
6) Set signing options & click "Sign File(s)" — pick a timestamp server (DigiCert recommended), keep SHA256, tick "Use same PFX", then sign.
After signing, Windows will display a verified publisher dialog when users run the signed file.

See it in action: https://youtu.be/7yWXCK3QdTw

<img width="1076" height="1022" alt="Screenshot 2026-04-07 222408" src="https://github.com/user-attachments/assets/9f02533c-6a6b-4500-a13b-0164e43b616f" />
