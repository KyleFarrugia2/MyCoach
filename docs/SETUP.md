# First-time setup (required before build)

Apple’s command-line tools on this Mac have not accepted the Xcode license yet.
Until that is done, **git**, **python3**, **swift**, and **xcodebuild** from `/usr/bin` will refuse to run.

## 1. Accept the Xcode license

Open **Terminal.app** and run:

```bash
sudo xcodebuild -license accept
```

Enter your Mac password when prompted.

## 2. Verify tooling

```bash
xcodebuild -version
swift --version
python3 --version
git --version
```

## 3. Open My Coach

```bash
open /Users/kylefarrugia/Desktop/MyCoach/MyCoach.xcodeproj
```

In Xcode:

1. Select the **MyCoach** scheme
2. Choose an iPhone simulator
3. Set your Signing Team
4. Product → Run
5. Product → Test

## 4. After adding/removing Swift files

```bash
cd /Users/kylefarrugia/Desktop/MyCoach
python3 Scripts/generate_xcode_project.py
```

Then continue development. Once the license is accepted, ask the agent to compile, run tests, and fix any remaining issues.
