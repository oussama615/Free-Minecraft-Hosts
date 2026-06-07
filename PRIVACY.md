# Privacy Notice

StrawIO VoiceChat is developed by StrawIO Studio.

## Current Android foundation phase

This phase does not include backend communication, a Minecraft plugin, voice relay, or real voice transmission. The app displays branding and local connection state placeholders while preparing safe architecture for future integrations.

## What the app does not do today

- No microphone recording.
- No audio storage.
- No analytics.
- No advertisements.
- No tracking or fingerprinting.
- No user account creation.
- No personal data upload.
- No background data collection.

## Device identity

On first launch, the app prepares a locally generated cryptographic device key through Android Keystore. The private key is non-exportable. Only a public key identifier is stored in normal app storage. This is a foundation for future challenge-response authentication and is not a user password.

## Future voice features

Future voice functionality will require explicit Android microphone permission. Audio should not be stored by default, and any future network behavior must be documented before release.
