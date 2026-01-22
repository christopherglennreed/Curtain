# Curtain 
**A macOS menu bar app that helps you focus by dimming everything except your active window.**
** AI CREATED README **
Curtain creates a semi-transparent overlay across your screen(s), cutting out a clear window around your focused application. Perfect for reducing visual distractions and improving concentration during deep work sessions.



![Curtain-Photo](photo-web)
![Curtain-term](photo-terminal)
## Features

### 🎯 Focus Mode
- **Smart Window Detection** - Automatically tracks your frontmost window
- **Lock to Window** - Pin the focus to a specific window, even when switching apps
- **Multi-Monitor Support** - Works seamlessly across all connected displays
- **Real-time Updates** - Cutout follows your window as you move and resize it (5 updates/second)

### 🎨 Customization
- **Adjustable Dim Levels** - Choose from 60%, 70%, 80%, 90%, or 95% darkness
- **Custom Colors** - Select from:
  - Black (default)
  - Blue Light Filter (warm orange tint for evening work)
  - Sepia (vintage, easy on the eyes)
  - Gray (subtle dimming)

### ⌨️ Keyboard Shortcuts
- `Cmd+Opt+D` - Toggle dim on/off
- `Cmd+Opt+L` - Lock to current window
- `Cmd+Opt+U` - Unlock window
- `Cmd+Opt+[` - Decrease dim by 5%
- `Cmd+Opt+]` - Increase dim by 5%

###  Convenience
- **Menu Bar Access** - Quick access to all features
- **Lightweight** - Minimal CPU and memory usage

## Installation

### Build from Source

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/curtain.git
   cd curtain
   ```

2. **Build the app:**
   ```bash
   swift build
   ```

3. **Run Curtain:**
   ```bash
   .build/debug/Curtain &
   ```

### Quick Run Command
For development, use this command to restart the app:
```bash
cd /path/to/curtain && killall Curtain 2>/dev/null; rm -rf .build && swift build && .build/debug/Curtain &
```

## Usage

### Getting Started

1. **Launch Curtain** - The 🎭 icon appears in your menu bar
2. **Enable Accessibility** - On first launch, you'll be prompted to grant Accessibility permissions
   - Go to System Settings > Privacy & Security > Accessibility
   - Enable Curtain
3. **Select Dim Level** - Click the menu bar icon and choose a dim percentage
4. **Focus!** - Your active window stays clear while everything else dims

### Basic Workflow

**Auto-Follow Mode (Default):**
- The clear cutout automatically follows whichever window is frontmost
- Switch between apps and the focus moves with you

**Locked Mode:**
1. Focus the window you want to work in
2. Click 🎭 → "Lock to Current Window" (or press `Cmd+Opt+L`)
3. Now you can switch to other apps to reference information, but the locked window stays clear
4. Click "Unlock Window" (or press `Cmd+Opt+U`) to return to auto-follow mode

### Tips & Tricks

- **Quick Toggle** - Use `Cmd+Opt+D` to instantly turn dimming on/off
- **Fine-tune Darkness** - Use `Cmd+Opt+[` and `]` to adjust dim level in 5% increments
- **Evening Work** - Switch to "Blue Light Filter" color to reduce eye strain
- **Multiple Monitors** - All screens dim except where your focused window is located

## How It Works

Curtain uses macOS's window management APIs to:

1. **Detect Windows** - Queries the system for all visible windows using `CGWindowListCopyWindowInfo`
2. **Track Focus** - Monitors workspace notifications to know which app is frontmost
3. **Create Overlays** - Generates borderless, transparent windows at the `.floating` level
4. **Cut Out Focus** - Uses Core Graphics to draw a dimmed overlay with a clear rectangular cutout
5. **Update Continuously** - Refreshes the cutout position 5 times per second to follow window movements

### Technical Details

- **Language:** Swift 5.9
- **Minimum macOS:** 13.0 (Ventura)
- **Frameworks:** Cocoa, ServiceManagement
- **Architecture:** Menu bar app (LSUIElement)
- **Update Frequency:** 5 Hz (200ms interval)
- **Rendering:** Core Graphics with blend mode `.clear` for cutouts

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building)
- Accessibility permissions (granted on first launch)

## Limitations

- **Window Detection** - Some apps (like full-screen games) may not be detected properly
- **Performance** - On very slow machines, the 5 Hz update rate might cause slight lag
- **App Store** - Not available on the App Store (uses private APIs for window management)

## Troubleshooting

### App crashes when unlocking
- This is a known issue being worked on
- Workaround: Restart the app after crashes

### Menu bar icon doesn't appear
- Check if the app is running: `ps aux | grep Curtain`
- Your menu bar might be crowded - look for the >> overflow menu
- Try restarting the app

### Cutout gets "stuck" or doesn't follow window
- The cutout updates 5 times per second - very fast movements may lag slightly
- Try locking to the window (`Cmd+Opt+L`) for more stable tracking
- Restart the app if the issue persists

### Dim applies to focused window
- This usually happens after multiple lock/unlock cycles
- Restart the app to reset the overlay state

## Development
![Curtain-app](photo-app)
### Project Structure
```
curtain/
├── Package.swift           # Swift Package Manager configuration
├── Sources/
│   └── Curtain/
│       ├── main.swift      # Main app logic
│       └── Resources/
│           └── curtain.png # Menu bar icon
├── curtain.png            # App icon/screenshot
└── README.md
```

### Building for Release
```bash
swift build -c release
```

The release binary will be at `.build/release/Curtain`

### Contributing
Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License - feel free to use this in your own projects!

## Credits

Created by Christopher Reed

Inspired by the need for better focus tools on macOS.

---

**Note:** Curtain is not affiliated with or endorsed by Apple Inc. This is an independent open-source project.
