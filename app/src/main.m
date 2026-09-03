#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface ZigAgentApp : NSObject <NSApplicationDelegate, NSTableViewDelegate, NSTableViewDataSource, WKNavigationDelegate, NSTextFieldDelegate>

// Main Window & Master Layout
@property (strong) NSWindow *window;
@property (strong) NSVisualEffectView *rootVisualEffect;
@property (strong) NSSplitView *masterSplitView;

// Left Collapsible Sidebar: Sessions Drawer
@property (strong) NSView *sidebarView;
@property (strong) NSTableView *sessionsTableView;
@property (strong) NSMutableArray<NSDictionary *> *sessionsList;
@property (assign) BOOL isSidebarVisible;

// Center Panel: Chat & Action Stream
@property (strong) NSView *chatCenterView;
@property (strong) NSTextView *chatLogTextView;
@property (strong) NSScrollView *chatLogScrollView;
@property (strong) NSTextField *chatInputField;
@property (strong) NSButton *sendActionButton;
@property (strong) NSButton *interruptActionButton;
@property (strong) NSTextField *topStatusBadge;

// Right Multi-Dock Panel: Browser / Preview / Terminal / Settings
@property (strong) NSView *rightDockView;
@property (strong) NSSegmentedControl *dockTabSelector;
@property (strong) NSView *browserContainer;
@property (strong) WKWebView *builtInWebView;
@property (strong) NSTextField *browserUrlField;

@property (strong) NSView *previewContainer;
@property (strong) NSTextView *codeEditorTextView;
@property (strong) WKWebView *markdownRenderWebView;
@property (strong) NSSegmentedControl *previewModeToggle;
@property (strong) NSTextField *currentPreviewFilePathField;
@property (strong) NSString *currentLoadedFilePath;

@property (strong) NSView *terminalContainer;
@property (strong) NSTextView *terminalOutputTextView;
@property (strong) NSTextField *terminalInputField;

@property (strong) NSView *settingsContainer;
@property (strong) NSPopUpButton *modelPopup;
@property (strong) NSPopUpButton *reasoningPopup;
@property (strong) NSButton *unboundedCheck;
@property (strong) NSButton *streamingCheck;
@property (strong) NSTextField *groqKeyInput;
@property (strong) NSTextField *openrouterKeyInput;

@property (strong) NSTask *currentAgentTask;
@property (strong) NSString *activeModelName;

@end

@implementation ZigAgentApp

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    self.activeModelName = @"openai/gpt-oss-120b";
    self.isSidebarVisible = YES;

    // Window Setup: Ultra-crisp modern geometry
    NSRect screenRect = [[NSScreen mainScreen] visibleFrame];
    CGFloat winW = MIN(1380.0, screenRect.size.width - 60.0);
    CGFloat winH = MIN(880.0, screenRect.size.height - 60.0);
    NSRect winRect = NSMakeRect((screenRect.size.width - winW) / 2.0, (screenRect.size.height - winH) / 2.0, winW, winH);

    self.window = [[NSWindow alloc] initWithContentRect:winRect
                                              styleMask:(NSWindowStyleMaskTitled |
                                                         NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskMiniaturizable |
                                                         NSWindowStyleMaskResizable |
                                                         NSWindowStyleMaskFullSizeContentView)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];

    self.window.title = @"ZigAgent // Autonomous Cognitive Studio";
    self.window.titlebarAppearsTransparent = YES;
    self.window.titleVisibility = NSWindowTitleHidden;
    self.window.backgroundColor = [NSColor colorWithCalibratedRed:0.04 green:0.05 blue:0.07 alpha:1.0];
    self.window.minSize = NSMakeSize(960, 600);

    // Root Slate Glass Vibrancy
    self.rootVisualEffect = [[NSVisualEffectView alloc] initWithFrame:self.window.contentView.bounds];
    self.rootVisualEffect.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.rootVisualEffect.material = NSVisualEffectMaterialUnderWindowBackground;
    self.rootVisualEffect.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    self.rootVisualEffect.state = NSVisualEffectStateActive;
    [self.window.contentView addSubview:self.rootVisualEffect];

    [self setupTopToolbar];
    [self setupMasterSplitView];
    [self setupSidebar];
    [self setupChatCenter];
    [self setupRightMultiDock];

    [self loadSettingsFromDisk];
    [self loadInitialWorkspacePreview];

    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeFirstResponder:self.chatInputField];
}

#pragma mark - Theme & Styling Helpers

- (NSColor *)slateBackground {
    return [NSColor colorWithCalibratedRed:0.04 green:0.05 blue:0.07 alpha:0.96];
}

- (NSColor *)slateCardBg {
    return [NSColor colorWithCalibratedRed:0.07 green:0.09 blue:0.12 alpha:0.92];
}

- (NSColor *)slateBorderColor {
    return [NSColor colorWithCalibratedRed:0.15 green:0.18 blue:0.24 alpha:0.8];
}

- (NSColor *)bloodstoneOrange {
    return [NSColor colorWithCalibratedRed:1.00 green:0.42 blue:0.21 alpha:1.0];
}

- (NSColor *)aquamarineAccent {
    return [NSColor colorWithCalibratedRed:0.19 green:0.77 blue:0.55 alpha:1.0];
}

- (NSFont *)monoFont:(CGFloat)size bold:(BOOL)bold {
    NSFont *f = bold ? [NSFont fontWithName:@"JetBrainsMono-Bold" size:size] : [NSFont fontWithName:@"JetBrainsMono-Regular" size:size];
    if (!f) {
        f = bold ? [NSFont fontWithName:@"SFMono-Bold" size:size] : [NSFont fontWithName:@"SFMono-Regular" size:size];
    }
    if (!f) {
        f = bold ? [NSFont fontWithName:@"Menlo-Bold" size:size] : [NSFont fontWithName:@"Menlo" size:size];
    }
    return f ?: (bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size]);
}

- (void)applySpectralShadow:(NSView *)view glowColor:(NSColor *)glowColor radius:(CGFloat)radius {
    view.wantsLayer = YES;
    view.layer.shadowColor = glowColor.CGColor;
    view.layer.shadowOpacity = 0.25;
    view.layer.shadowRadius = radius;
    view.layer.shadowOffset = CGSizeMake(0, -2);
}

#pragma mark - Top Toolbar

- (void)setupTopToolbar {
    CGFloat barH = 50.0;
    NSRect barRect = NSMakeRect(0, self.window.contentView.bounds.size.height - barH, self.window.contentView.bounds.size.width, barH);
    NSView *toolbarView = [[NSView alloc] initWithFrame:barRect];
    toolbarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    toolbarView.wantsLayer = YES;
    toolbarView.layer.backgroundColor = [self slateCardBg].CGColor;
    [self.rootVisualEffect addSubview:toolbarView];

    // Left Toggle Sessions Button
    NSButton *toggleSidebarBtn = [[NSButton alloc] initWithFrame:NSMakeRect(78, 11, 100, 28)];
    toggleSidebarBtn.title = @"☰ Sessions";
    toggleSidebarBtn.font = [self monoFont:11 bold:YES];
    toggleSidebarBtn.bezelStyle = NSBezelStyleRounded;
    toggleSidebarBtn.contentTintColor = [NSColor colorWithCalibratedWhite:0.8 alpha:1.0];
    toggleSidebarBtn.target = self;
    toggleSidebarBtn.action = @selector(toggleSidebar);
    [toolbarView addSubview:toggleSidebarBtn];

    // Logo & Title
    NSTextField *logoLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(188, 13, 220, 24)];
    logoLbl.stringValue = @"⚡ ZIGAGENT // STUDIO";
    logoLbl.font = [self monoFont:13 bold:YES];
    logoLbl.textColor = [self aquamarineAccent];
    logoLbl.bezeled = NO;
    logoLbl.drawsBackground = NO;
    logoLbl.editable = NO;
    [toolbarView addSubview:logoLbl];

    // Top Status & Model Telemetry Badge
    self.topStatusBadge = [[NSTextField alloc] initWithFrame:NSMakeRect(400, 13, 380, 24)];
    self.topStatusBadge.autoresizingMask = NSViewWidthSizable;
    self.topStatusBadge.stringValue = [NSString stringWithFormat:@"Model: %@ • 🧠 max • Context: 1%%", self.activeModelName];
    self.topStatusBadge.font = [self monoFont:11 bold:NO];
    self.topStatusBadge.textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
    self.topStatusBadge.bezeled = NO;
    self.topStatusBadge.drawsBackground = NO;
    self.topStatusBadge.editable = NO;
    [toolbarView addSubview:self.topStatusBadge];

    // Right Multi-Dock Segmented Selector (Browser / Preview / Terminal / Settings)
    self.dockTabSelector = [NSSegmentedControl segmentedControlWithLabels:@[@"👁️ Preview", @"🌐 Browser", @"⚡ Terminal", @"⚙️ Config"]
                                                             trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                   target:self
                                                                   action:@selector(dockTabChanged:)];
    self.dockTabSelector.frame = NSMakeRect(toolbarView.bounds.size.width - 390, 10, 374, 30);
    self.dockTabSelector.autoresizingMask = NSViewMinXMargin;
    self.dockTabSelector.selectedSegment = 0;
    self.dockTabSelector.font = [self monoFont:11 bold:YES];
    [toolbarView addSubview:self.dockTabSelector];
}

#pragma mark - Master 3-Column Split View

- (void)setupMasterSplitView {
    CGFloat barH = 50.0;
    NSRect splitRect = NSMakeRect(0, 0, self.window.contentView.bounds.size.width, self.window.contentView.bounds.size.height - barH);
    self.masterSplitView = [[NSSplitView alloc] initWithFrame:splitRect];
    self.masterSplitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.masterSplitView.vertical = YES;
    self.masterSplitView.dividerStyle = NSSplitViewDividerStyleThin;
    [self.rootVisualEffect addSubview:self.masterSplitView];
}

#pragma mark - Left Sidebar (Sessions Drawer)

- (void)setupSidebar {
    self.sidebarView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 240, self.masterSplitView.bounds.size.height)];
    self.sidebarView.wantsLayer = YES;
    self.sidebarView.layer.backgroundColor = [self slateBackground].CGColor;

    // Header
    NSTextField *sideHdr = [[NSTextField alloc] initWithFrame:NSMakeRect(14, self.sidebarView.bounds.size.height - 36, 120, 22)];
    sideHdr.autoresizingMask = NSViewMinYMargin;
    sideHdr.stringValue = @"SESSIONS";
    sideHdr.font = [self monoFont:11 bold:YES];
    sideHdr.textColor = [self bloodstoneOrange];
    sideHdr.bezeled = NO;
    sideHdr.drawsBackground = NO;
    sideHdr.editable = NO;
    [self.sidebarView addSubview:sideHdr];

    NSButton *newBtn = [[NSButton alloc] initWithFrame:NSMakeRect(self.sidebarView.bounds.size.width - 86, self.sidebarView.bounds.size.height - 38, 72, 24)];
    newBtn.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
    newBtn.title = @"+ New";
    newBtn.font = [self monoFont:10 bold:YES];
    newBtn.bezelStyle = NSBezelStyleRounded;
    newBtn.contentTintColor = [self aquamarineAccent];
    newBtn.target = self;
    newBtn.action = @selector(startNewSession);
    [self.sidebarView addSubview:newBtn];

    // Sessions Table
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 44, self.sidebarView.bounds.size.width - 20, self.sidebarView.bounds.size.height - 88)];
    scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSNoBorder;
    scroll.drawsBackground = NO;

    self.sessionsList = [NSMutableArray arrayWithArray:@[
        @{@"title": @"Full Native Architecture Refactor", @"time": @"Just now", @"id": @"ses_101"},
        @{@"title": @"OmniLattice Continuity & Ledgers", @"time": @"1 hour ago", @"id": @"ses_102"},
        @{@"title": @"Zero-GC Arena Memory Optimization", @"time": @"Yesterday", @"id": @"ses_103"}
    ]];

    self.sessionsTableView = [[NSTableView alloc] initWithFrame:scroll.bounds];
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"SessionCol"];
    col.width = scroll.bounds.size.width - 20;
    [self.sessionsTableView addTableColumn:col];
    self.sessionsTableView.delegate = self;
    self.sessionsTableView.dataSource = self;
    self.sessionsTableView.headerView = nil;
    self.sessionsTableView.backgroundColor = [NSColor clearColor];

    scroll.documentView = self.sessionsTableView;
    [self.sidebarView addSubview:scroll];

    // Bottom Delete / Clear Actions
    NSButton *delBtn = [[NSButton alloc] initWithFrame:NSMakeRect(10, 10, 105, 26)];
    delBtn.title = @"🗑️ Delete";
    delBtn.font = [self monoFont:10 bold:NO];
    delBtn.bezelStyle = NSBezelStyleRounded;
    delBtn.contentTintColor = [NSColor colorWithCalibratedRed:1.0 green:0.3 blue:0.3 alpha:1.0];
    delBtn.target = self;
    delBtn.action = @selector(deleteSelectedSession);
    [self.sidebarView addSubview:delBtn];

    NSButton *clearBtn = [[NSButton alloc] initWithFrame:NSMakeRect(125, 10, 105, 26)];
    clearBtn.title = @"🧹 Clear All";
    clearBtn.font = [self monoFont:10 bold:NO];
    clearBtn.bezelStyle = NSBezelStyleRounded;
    clearBtn.contentTintColor = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
    clearBtn.target = self;
    clearBtn.action = @selector(clearAllSessions);
    [self.sidebarView addSubview:clearBtn];

    [self.masterSplitView addSubview:self.sidebarView];
}

#pragma mark - Center Chat & Action Feed

- (void)setupChatCenter {
    self.chatCenterView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 520, self.masterSplitView.bounds.size.height)];
    self.chatCenterView.wantsLayer = YES;
    self.chatCenterView.layer.backgroundColor = [self slateCardBg].CGColor;
    [self applySpectralShadow:self.chatCenterView glowColor:[NSColor blackColor] radius:10];

    // Chat Transcript Area
    CGFloat inputH = 56.0;
    NSRect logRect = NSMakeRect(14, inputH + 20, self.chatCenterView.bounds.size.width - 28, self.chatCenterView.bounds.size.height - inputH - 30);
    self.chatLogScrollView = [[NSScrollView alloc] initWithFrame:logRect];
    self.chatLogScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.chatLogScrollView.hasVerticalScroller = YES;
    self.chatLogScrollView.borderType = NSNoBorder;
    self.chatLogScrollView.drawsBackground = NO;

    self.chatLogTextView = [[NSTextView alloc] initWithFrame:self.chatLogScrollView.bounds];
    self.chatLogTextView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.chatLogTextView.backgroundColor = [NSColor clearColor];
    self.chatLogTextView.font = [self monoFont:12 bold:NO];
    self.chatLogTextView.textColor = [NSColor colorWithCalibratedWhite:0.92 alpha:1.0];
    self.chatLogTextView.editable = NO;
    self.chatLogTextView.textContainerInset = NSMakeSize(10, 10);

    self.chatLogScrollView.documentView = self.chatLogTextView;
    [self.chatCenterView addSubview:self.chatLogScrollView];

    // Floating Input Card Container (Spectral 3D Glass Pill)
    NSRect inputRect = NSMakeRect(14, 14, self.chatCenterView.bounds.size.width - 28, inputH);
    NSBox *inputCard = [[NSBox alloc] initWithFrame:inputRect];
    inputCard.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    inputCard.boxType = NSBoxCustom;
    inputCard.fillColor = [NSColor colorWithCalibratedRed:0.05 green:0.07 blue:0.09 alpha:0.98];
    inputCard.borderColor = [self slateBorderColor];
    inputCard.borderWidth = 1.0;
    inputCard.cornerRadius = 12.0;
    [self applySpectralShadow:inputCard glowColor:[self bloodstoneOrange] radius:4];
    [self.chatCenterView addSubview:inputCard];

    // Prompt Indicator `>`
    NSTextField *promptPrefix = [[NSTextField alloc] initWithFrame:NSMakeRect(12, 16, 20, 24)];
    promptPrefix.stringValue = @">";
    promptPrefix.font = [self monoFont:14 bold:YES];
    promptPrefix.textColor = [NSColor colorWithCalibratedRed:0.66 green:0.33 blue:0.97 alpha:1.0]; // Purple prompt
    promptPrefix.bezeled = NO;
    promptPrefix.drawsBackground = NO;
    promptPrefix.editable = NO;
    [inputCard.contentView addSubview:promptPrefix];

    // Main Chat Input Field
    CGFloat btnW = 74.0;
    self.chatInputField = [[NSTextField alloc] initWithFrame:NSMakeRect(32, 10, inputCard.bounds.size.width - btnW - 44, 34)];
    self.chatInputField.autoresizingMask = NSViewWidthSizable;
    self.chatInputField.placeholderString = @"Message Ziggy or enter directive (!<cmd> for shell)...";
    self.chatInputField.font = [self monoFont:12 bold:NO];
    self.chatInputField.textColor = [NSColor whiteColor];
    self.chatInputField.bezeled = NO;
    self.chatInputField.drawsBackground = NO;
    self.chatInputField.delegate = self;
    self.chatInputField.target = self;
    self.chatInputField.action = @selector(sendCurrentMessage);
    [inputCard.contentView addSubview:self.chatInputField];

    // Send Action Button
    self.sendActionButton = [[NSButton alloc] initWithFrame:NSMakeRect(inputCard.bounds.size.width - btnW - 10, 11, btnW, 32)];
    self.sendActionButton.autoresizingMask = NSViewMinXMargin;
    self.sendActionButton.title = @"⚡ SEND";
    self.sendActionButton.font = [self monoFont:11 bold:YES];
    self.sendActionButton.bezelStyle = NSBezelStyleRounded;
    self.sendActionButton.contentTintColor = [self bloodstoneOrange];
    self.sendActionButton.target = self;
    self.sendActionButton.action = @selector(sendCurrentMessage);
    [inputCard.contentView addSubview:self.sendActionButton];

    [self.masterSplitView addSubview:self.chatCenterView];

    [self appendSignalMessage:@"⚡ ZIGAGENT NATIVE ACTION RUNTIME READY\n• Signal Filter: Active (Zero metadata bloat)\n• Built-in Browser, Code Editor, and Live Preview operational.\n\n" type:@"system"];
}

#pragma mark - Right Multi-Dock (Browser / Preview / Terminal / Settings)

- (void)setupRightMultiDock {
    self.rightDockView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 560, self.masterSplitView.bounds.size.height)];
    self.rightDockView.wantsLayer = YES;
    self.rightDockView.layer.backgroundColor = [self slateBackground].CGColor;

    [self setupPreviewPanel];
    [self setupBrowserPanel];
    [self setupTerminalPanel];
    [self setupSettingsPanel];

    [self.browserContainer setHidden:YES];
    [self.terminalContainer setHidden:YES];
    [self.settingsContainer setHidden:YES];
    [self.previewContainer setHidden:NO];

    [self.masterSplitView addSubview:self.rightDockView];
}

#pragma mark - 1. Built-in Artifact & Preview Panel

- (void)setupPreviewPanel {
    self.previewContainer = [[NSView alloc] initWithFrame:self.rightDockView.bounds];
    self.previewContainer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.rightDockView addSubview:self.previewContainer];

    // Header Controls: File path + Toggle Code/Render + Save button
    CGFloat topH = 42.0;
    NSView *header = [[NSView alloc] initWithFrame:NSMakeRect(10, self.previewContainer.bounds.size.height - topH - 8, self.previewContainer.bounds.size.width - 20, topH)];
    header.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    header.wantsLayer = YES;
    header.layer.backgroundColor = [self slateCardBg].CGColor;
    header.layer.cornerRadius = 8.0;
    header.layer.borderColor = [self slateBorderColor].CGColor;
    header.layer.borderWidth = 1.0;
    [self.previewContainer addSubview:header];

    self.currentPreviewFilePathField = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 8, header.bounds.size.width - 240, 24)];
    self.currentPreviewFilePathField.autoresizingMask = NSViewWidthSizable;
    self.currentPreviewFilePathField.stringValue = @"src/main.zig";
    self.currentPreviewFilePathField.font = [self monoFont:11 bold:YES];
    self.currentPreviewFilePathField.textColor = [self aquamarineAccent];
    self.currentPreviewFilePathField.bezeled = NO;
    self.currentPreviewFilePathField.drawsBackground = NO;
    self.currentPreviewFilePathField.editable = YES;
    self.currentPreviewFilePathField.target = self;
    self.currentPreviewFilePathField.action = @selector(openCustomFilePath);
    [header addSubview:self.currentPreviewFilePathField];

    self.previewModeToggle = [NSSegmentedControl segmentedControlWithLabels:@[@"Code", @"Render"]
                                                               trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                     target:self
                                                                     action:@selector(previewModeChanged:)];
    self.previewModeToggle.frame = NSMakeRect(header.bounds.size.width - 220, 7, 120, 26);
    self.previewModeToggle.autoresizingMask = NSViewMinXMargin;
    self.previewModeToggle.selectedSegment = 0;
    self.previewModeToggle.font = [self monoFont:10 bold:YES];
    [header addSubview:self.previewModeToggle];

    NSButton *saveBtn = [[NSButton alloc] initWithFrame:NSMakeRect(header.bounds.size.width - 92, 6, 82, 28)];
    saveBtn.autoresizingMask = NSViewMinXMargin;
    saveBtn.title = @"💾 Save";
    saveBtn.font = [self monoFont:10 bold:YES];
    saveBtn.bezelStyle = NSBezelStyleRounded;
    saveBtn.contentTintColor = [self bloodstoneOrange];
    saveBtn.target = self;
    saveBtn.action = @selector(saveCurrentPreviewFile);
    [header addSubview:saveBtn];

    // Source Code Editor Text View
    NSRect editorRect = NSMakeRect(10, 10, self.previewContainer.bounds.size.width - 20, self.previewContainer.bounds.size.height - topH - 24);
    NSScrollView *editorScroll = [[NSScrollView alloc] initWithFrame:editorRect];
    editorScroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    editorScroll.hasVerticalScroller = YES;
    editorScroll.hasHorizontalScroller = YES;
    editorScroll.borderType = NSLineBorder;
    editorScroll.wantsLayer = YES;
    editorScroll.layer.borderColor = [self slateBorderColor].CGColor;
    editorScroll.layer.borderWidth = 1.0;
    editorScroll.layer.cornerRadius = 8.0;

    self.codeEditorTextView = [[NSTextView alloc] initWithFrame:editorScroll.bounds];
    self.codeEditorTextView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.codeEditorTextView.backgroundColor = [self slateCardBg];
    self.codeEditorTextView.font = [self monoFont:12 bold:NO];
    self.codeEditorTextView.textColor = [NSColor colorWithCalibratedWhite:0.95 alpha:1.0];
    self.codeEditorTextView.textContainerInset = NSMakeSize(12, 12);
    self.codeEditorTextView.automaticQuoteSubstitutionEnabled = NO;

    editorScroll.documentView = self.codeEditorTextView;
    [self.previewContainer addSubview:editorScroll];

    // Markdown / HTML Live Render WebView
    self.markdownRenderWebView = [[WKWebView alloc] initWithFrame:editorRect];
    self.markdownRenderWebView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.markdownRenderWebView.wantsLayer = YES;
    self.markdownRenderWebView.layer.cornerRadius = 8.0;
    self.markdownRenderWebView.layer.borderColor = [self slateBorderColor].CGColor;
    self.markdownRenderWebView.layer.borderWidth = 1.0;
    [self.markdownRenderWebView setHidden:YES];
    [self.previewContainer addSubview:self.markdownRenderWebView];
}

- (void)previewModeChanged:(NSSegmentedControl *)sender {
    if (sender.selectedSegment == 0) {
        [self.codeEditorTextView.enclosingScrollView setHidden:NO];
        [self.markdownRenderWebView setHidden:YES];
    } else {
        [self.codeEditorTextView.enclosingScrollView setHidden:YES];
        [self.markdownRenderWebView setHidden:NO];
        [self renderCodeToHtmlView:self.codeEditorTextView.string filePath:self.currentPreviewFilePathField.stringValue];
    }
}

- (void)renderCodeToHtmlView:(NSString *)rawContent filePath:(NSString *)path {
    NSString *ext = [path pathExtension].lowercaseString;
    NSString *html = @"";

    if ([ext isEqualToString:@"html"] || [ext isEqualToString:@"htm"]) {
        html = rawContent;
    } else if ([ext isEqualToString:@"md"] || [ext isEqualToString:@"markdown"]) {
        // Minimal fast markdown converter wrapper
        NSString *escaped = [rawContent stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
        escaped = [escaped stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
        escaped = [escaped stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
        escaped = [escaped stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>\n"];

        html = [NSString stringWithFormat:
            @"<!DOCTYPE html><html><head><style>"
            @"body { font-family: -apple-system, sans-serif; background: #0e1217; color: #e2e8f0; padding: 24px; line-height: 1.6; }"
            @"h1, h2, h3 { color: #00f2fe; }"
            @"code { font-family: 'JetBrains Mono', monospace; background: #1a202c; padding: 2px 6px; border-radius: 4px; color: #31c48d; }"
            @"pre { background: #13171e; padding: 16px; border-radius: 8px; border: 1px solid #2d3748; overflow-x: auto; }"
            @"</style></head><body>%@</body></html>", escaped];
    } else {
        NSString *escaped = [rawContent stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
        html = [NSString stringWithFormat:
            @"<!DOCTYPE html><html><head><style>"
            @"body { font-family: 'JetBrains Mono', monospace; background: #0a0d12; color: #cbd5e1; padding: 18px; }"
            @"pre { margin: 0; white-space: pre-wrap; word-break: break-all; }"
            @"</style></head><body><pre>%@</pre></body></html>", escaped];
    }

    [self.markdownRenderWebView loadHTMLString:html baseURL:nil];
}

#pragma mark - 2. Built-in Browser Panel

- (void)setupBrowserPanel {
    self.browserContainer = [[NSView alloc] initWithFrame:self.rightDockView.bounds];
    self.browserContainer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.rightDockView addSubview:self.browserContainer];

    // Top Navigation Bar
    CGFloat topH = 42.0;
    NSView *navBar = [[NSView alloc] initWithFrame:NSMakeRect(10, self.browserContainer.bounds.size.height - topH - 8, self.browserContainer.bounds.size.width - 20, topH)];
    navBar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    navBar.wantsLayer = YES;
    navBar.layer.backgroundColor = [self slateCardBg].CGColor;
    navBar.layer.cornerRadius = 8.0;
    navBar.layer.borderColor = [self slateBorderColor].CGColor;
    navBar.layer.borderWidth = 1.0;
    [self.browserContainer addSubview:navBar];

    NSButton *backBtn = [[NSButton alloc] initWithFrame:NSMakeRect(8, 7, 30, 26)];
    backBtn.title = @"◀";
    backBtn.font = [self monoFont:11 bold:YES];
    backBtn.bezelStyle = NSBezelStyleRounded;
    backBtn.target = self;
    backBtn.action = @selector(browserGoBack);
    [navBar addSubview:backBtn];

    NSButton *reloadBtn = [[NSButton alloc] initWithFrame:NSMakeRect(42, 7, 30, 26)];
    reloadBtn.title = @"🔄";
    reloadBtn.font = [self monoFont:11 bold:YES];
    reloadBtn.bezelStyle = NSBezelStyleRounded;
    reloadBtn.target = self;
    reloadBtn.action = @selector(browserReload);
    [navBar addSubview:reloadBtn];

    self.browserUrlField = [[NSTextField alloc] initWithFrame:NSMakeRect(80, 8, navBar.bounds.size.width - 90, 24)];
    self.browserUrlField.autoresizingMask = NSViewWidthSizable;
    self.browserUrlField.stringValue = @"http://localhost:4040";
    self.browserUrlField.font = [self monoFont:11 bold:NO];
    self.browserUrlField.textColor = [NSColor whiteColor];
    self.browserUrlField.bezeled = NO;
    self.browserUrlField.drawsBackground = NO;
    self.browserUrlField.target = self;
    self.browserUrlField.action = @selector(browserNavigate);
    [navBar addSubview:self.browserUrlField];

    // WebKit View
    NSRect webRect = NSMakeRect(10, 10, self.browserContainer.bounds.size.width - 20, self.browserContainer.bounds.size.height - topH - 24);
    self.builtInWebView = [[WKWebView alloc] initWithFrame:webRect];
    self.builtInWebView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.builtInWebView.wantsLayer = YES;
    self.builtInWebView.layer.cornerRadius = 8.0;
    self.builtInWebView.layer.borderColor = [self slateBorderColor].CGColor;
    self.builtInWebView.layer.borderWidth = 1.0;
    [self.browserContainer addSubview:self.builtInWebView];

    [self browserNavigate];
}

- (void)browserNavigate {
    NSString *urlStr = self.browserUrlField.stringValue;
    if (![urlStr hasPrefix:@"http://"] && ![urlStr hasPrefix:@"https://"] && ![urlStr hasPrefix:@"file://"]) {
        urlStr = [NSString stringWithFormat:@"http://%@", urlStr];
        self.browserUrlField.stringValue = urlStr;
    }
    NSURL *url = [NSURL URLWithString:urlStr];
    if (url) {
        [self.builtInWebView loadRequest:[NSURLRequest requestWithURL:url]];
    }
}

- (void)browserGoBack {
    if ([self.builtInWebView canGoBack]) [self.builtInWebView goBack];
}

- (void)browserReload {
    [self.builtInWebView reload];
}

#pragma mark - 3. Built-in Terminal Panel

- (void)setupTerminalPanel {
    self.terminalContainer = [[NSView alloc] initWithFrame:self.rightDockView.bounds];
    self.terminalContainer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.rightDockView addSubview:self.terminalContainer];

    // Terminal Input at Bottom
    CGFloat inputH = 40.0;
    NSBox *termCard = [[NSBox alloc] initWithFrame:NSMakeRect(10, 10, self.terminalContainer.bounds.size.width - 20, inputH)];
    termCard.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    termCard.boxType = NSBoxCustom;
    termCard.fillColor = [NSColor colorWithCalibratedRed:0.06 green:0.08 blue:0.11 alpha:0.98];
    termCard.borderColor = [self slateBorderColor];
    termCard.borderWidth = 1.0;
    termCard.cornerRadius = 8.0;
    [self.terminalContainer addSubview:termCard];

    NSTextField *termPmt = [[NSTextField alloc] initWithFrame:NSMakeRect(8, 10, 18, 20)];
    termPmt.stringValue = @"$";
    termPmt.font = [self monoFont:12 bold:YES];
    termPmt.textColor = [self aquamarineAccent];
    termPmt.bezeled = NO;
    termPmt.drawsBackground = NO;
    termPmt.editable = NO;
    [termCard.contentView addSubview:termPmt];

    self.terminalInputField = [[NSTextField alloc] initWithFrame:NSMakeRect(28, 6, termCard.bounds.size.width - 36, 26)];
    self.terminalInputField.autoresizingMask = NSViewWidthSizable;
    self.terminalInputField.placeholderString = @"Execute shell command (e.g. ls, git status, zig build)...";
    self.terminalInputField.font = [self monoFont:11 bold:NO];
    self.terminalInputField.textColor = [NSColor whiteColor];
    self.terminalInputField.bezeled = NO;
    self.terminalInputField.drawsBackground = NO;
    self.terminalInputField.target = self;
    self.terminalInputField.action = @selector(executeTerminalInput);
    [termCard.contentView addSubview:self.terminalInputField];

    // Output Log Area
    NSRect termLogRect = NSMakeRect(10, inputH + 18, self.terminalContainer.bounds.size.width - 20, self.terminalContainer.bounds.size.height - inputH - 28);
    NSScrollView *termScroll = [[NSScrollView alloc] initWithFrame:termLogRect];
    termScroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    termScroll.hasVerticalScroller = YES;
    termScroll.borderType = NSLineBorder;
    termScroll.wantsLayer = YES;
    termScroll.layer.borderColor = [self slateBorderColor].CGColor;
    termScroll.layer.borderWidth = 1.0;
    termScroll.layer.cornerRadius = 8.0;

    self.terminalOutputTextView = [[NSTextView alloc] initWithFrame:termScroll.bounds];
    self.terminalOutputTextView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.terminalOutputTextView.backgroundColor = [self slateCardBg];
    self.terminalOutputTextView.font = [self monoFont:11 bold:NO];
    self.terminalOutputTextView.textColor = [NSColor colorWithCalibratedRed:0.25 green:0.85 blue:0.65 alpha:1.0];
    self.terminalOutputTextView.editable = NO;
    self.terminalOutputTextView.textContainerInset = NSMakeSize(10, 10);
    self.terminalOutputTextView.string = @"⚡ ZIGAGENT INTEGRATED TERMINAL READY\nType any shell command below to execute.\n\n";

    termScroll.documentView = self.terminalOutputTextView;
    [self.terminalContainer addSubview:termScroll];
}

- (void)executeTerminalInput {
    NSString *cmd = [self.terminalInputField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (cmd.length == 0) return;
    self.terminalInputField.stringValue = @"";

    [self appendTerminalOutput:[NSString stringWithFormat:@"\n$ %@\n", cmd]];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/bin/zsh";
        task.arguments = @[@"-c", cmd];
        NSPipe *pipe = [NSPipe pipe];
        task.standardOutput = pipe;
        task.standardError = pipe;
        [task launch];
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        [task waitUntilExit];
        NSString *outStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";

        dispatch_async(dispatch_get_main_queue(), ^{
            [self appendTerminalOutput:outStr];
        });
    });
}

- (void)appendTerminalOutput:(NSString *)text {
    NSAttributedString *attr = [[NSAttributedString alloc] initWithString:text attributes:@{
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:0.75 green:0.85 blue:0.95 alpha:1.0],
        NSFontAttributeName: [self monoFont:11 bold:NO]
    }];
    [self.terminalOutputTextView.textStorage appendAttributedString:attr];
    [self.terminalOutputTextView scrollRangeToVisible:NSMakeRange(self.terminalOutputTextView.string.length, 0)];
}

#pragma mark - 4. Built-in Settings Panel

- (void)setupSettingsPanel {
    self.settingsContainer = [[NSView alloc] initWithFrame:self.rightDockView.bounds];
    self.settingsContainer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.rightDockView addSubview:self.settingsContainer];

    NSBox *box = [[NSBox alloc] initWithFrame:NSMakeRect(10, 10, self.settingsContainer.bounds.size.width - 20, self.settingsContainer.bounds.size.height - 20)];
    box.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    box.boxType = NSBoxCustom;
    box.fillColor = [self slateCardBg];
    box.borderColor = [self slateBorderColor];
    box.borderWidth = 1.0;
    box.cornerRadius = 10.0;
    [self.settingsContainer addSubview:box];

    NSTextField *title = [[NSTextField alloc] initWithFrame:NSMakeRect(20, box.bounds.size.height - 40, box.bounds.size.width - 40, 24)];
    title.stringValue = @"⚙️ PREFERENCES & INFERENCE ROUTING";
    title.font = [self monoFont:13 bold:YES];
    title.textColor = [self bloodstoneOrange];
    title.bezeled = NO;
    title.drawsBackground = NO;
    title.editable = NO;
    [box.contentView addSubview:title];

    CGFloat y = box.bounds.size.height - 80;
    CGFloat labelW = 180;
    CGFloat fieldW = 280;

    // Model Selector
    [self addSettingRow:@"Active Model" y:y container:box.contentView labelW:labelW];
    self.modelPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(labelW + 20, y - 4, fieldW, 26) pullsDown:NO];
    [self.modelPopup addItemsWithTitles:@[
        @"openai/gpt-oss-120b (Frontier)",
        @"anthropic/claude-3.7-sonnet (Hybrid)",
        @"google/gemini-2.5-pro (1M Context)",
        @"deepseek/deepseek-r1 (Reasoning)",
        @"qwen/qwen3.8-27b (Stealth)",
        @"meta-llama/llama-3.3-70b-instruct",
        @"nvidia/nemotron-3-ultra-550b:free",
        @"poolside/laguna-s-2.1:free",
        @"ollama/qwen2.5-coder:32b"
    ]];
    [box.contentView addSubview:self.modelPopup];

    // Reasoning Level
    y -= 38;
    [self addSettingRow:@"Reasoning Depth" y:y container:box.contentView labelW:labelW];
    self.reasoningPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(labelW + 20, y - 4, fieldW, 26) pullsDown:NO];
    [self.reasoningPopup addItemsWithTitles:@[@"max (Deep 4-Pass Metacognition)", @"high", @"medium", @"low"]];
    [box.contentView addSubview:self.reasoningPopup];

    // Unbounded Autonomy Checkbox
    y -= 38;
    self.unboundedCheck = [NSButton checkboxWithTitle:@"⚡ Enable Unbounded Autonomy Loop (Infinite Steps)" target:self action:nil];
    self.unboundedCheck.frame = NSMakeRect(20, y, 400, 24);
    self.unboundedCheck.state = NSControlStateValueOn;
    self.unboundedCheck.font = [self monoFont:11 bold:NO];
    [box.contentView addSubview:self.unboundedCheck];

    // API Keys
    y -= 44;
    NSTextField *authHdr = [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 300, 20)];
    authHdr.stringValue = @"AI PROVIDER CREDENTIALS";
    authHdr.font = [self monoFont:11 bold:YES];
    authHdr.textColor = [self aquamarineAccent];
    authHdr.bezeled = NO;
    authHdr.drawsBackground = NO;
    authHdr.editable = NO;
    [box.contentView addSubview:authHdr];

    y -= 32;
    [self addSettingRow:@"Groq API Key" y:y container:box.contentView labelW:labelW];
    self.groqKeyInput = [[NSTextField alloc] initWithFrame:NSMakeRect(labelW + 20, y - 4, fieldW, 24)];
    self.groqKeyInput.placeholderString = @"gsk_...";
    self.groqKeyInput.font = [self monoFont:11 bold:NO];
    [box.contentView addSubview:self.groqKeyInput];

    y -= 32;
    [self addSettingRow:@"OpenRouter Key" y:y container:box.contentView labelW:labelW];
    self.openrouterKeyInput = [[NSTextField alloc] initWithFrame:NSMakeRect(labelW + 20, y - 4, fieldW, 24)];
    self.openrouterKeyInput.placeholderString = @"sk-or-v1-...";
    self.openrouterKeyInput.font = [self monoFont:11 bold:NO];
    [box.contentView addSubview:self.openrouterKeyInput];

    // Save Button
    y -= 44;
    NSButton *saveBtn = [[NSButton alloc] initWithFrame:NSMakeRect(labelW + 20, y, 160, 32)];
    saveBtn.title = @"💾 Apply Settings";
    saveBtn.font = [self monoFont:11 bold:YES];
    saveBtn.bezelStyle = NSBezelStyleRounded;
    saveBtn.contentTintColor = [self bloodstoneOrange];
    saveBtn.target = self;
    saveBtn.action = @selector(saveSettingsToDisk);
    [box.contentView addSubview:saveBtn];
}

- (void)addSettingRow:(NSString *)title y:(CGFloat)y container:(NSView *)container labelW:(CGFloat)labelW {
    NSTextField *lbl = [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, labelW, 20)];
    lbl.stringValue = title;
    lbl.font = [self monoFont:11 bold:YES];
    lbl.textColor = [NSColor whiteColor];
    lbl.bezeled = NO;
    lbl.drawsBackground = NO;
    lbl.editable = NO;
    [container addSubview:lbl];
}

#pragma mark - Dock Tab Switching

- (void)dockTabChanged:(NSSegmentedControl *)sender {
    [self.previewContainer setHidden:(sender.selectedSegment != 0)];
    [self.browserContainer setHidden:(sender.selectedSegment != 1)];
    [self.terminalContainer setHidden:(sender.selectedSegment != 2)];
    [self.settingsContainer setHidden:(sender.selectedSegment != 3)];
}

- (void)toggleSidebar {
    self.isSidebarVisible = !self.isSidebarVisible;
    [self.sidebarView setHidden:!self.isSidebarVisible];
}

#pragma mark - File Preview & Saving

- (void)loadInitialWorkspacePreview {
    NSString *pwd = [[[NSProcessInfo processInfo] environment] objectForKey:@"PWD"] ?: [[NSFileManager defaultManager] currentDirectoryPath];
    NSString *mainZig = [NSString stringWithFormat:@"%@/ziggy/src/main.zig", pwd];
    if (![[NSFileManager defaultManager] fileExistsAtPath:mainZig]) {
        mainZig = [NSString stringWithFormat:@"%@/src/main.zig", pwd];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:mainZig]) {
        [self loadFileIntoPreview:mainZig];
    }
}

- (void)loadFileIntoPreview:(NSString *)filePath {
    self.currentLoadedFilePath = filePath;
    self.currentPreviewFilePathField.stringValue = [filePath lastPathComponent];
    NSError *err = nil;
    NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&err];
    if (content) {
        self.codeEditorTextView.string = content;
        if (self.previewModeToggle.selectedSegment == 1) {
            [self renderCodeToHtmlView:content filePath:filePath];
        }
    }
}

- (void)openCustomFilePath {
    NSString *path = [self.currentPreviewFilePathField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [self loadFileIntoPreview:path];
    }
}

- (void)saveCurrentPreviewFile {
    if (self.currentLoadedFilePath.length > 0) {
        NSError *err = nil;
        [self.codeEditorTextView.string writeToFile:self.currentLoadedFilePath atomically:YES encoding:NSUTF8StringEncoding error:&err];
        if (!err) {
            [self appendSignalMessage:[NSString stringWithFormat:@"✔ Saved changes to: %@", [self.currentLoadedFilePath lastPathComponent]] type:@"tool"];
        }
    }
}

#pragma mark - Chat Dispatch & Signal Formatting

- (void)sendCurrentMessage {
    NSString *text = [self.chatInputField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) return;
    self.chatInputField.stringValue = @"";

    [self appendSignalMessage:text type:@"user"];

    // Direct Shell Pass-through
    if ([text hasPrefix:@"!"]) {
        NSString *cmd = [[text substringFromIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [self appendSignalMessage:[NSString stringWithFormat:@"⚡ Executing: %@", cmd] type:@"tool"];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSTask *task = [[NSTask alloc] init];
            task.launchPath = @"/bin/zsh";
            task.arguments = @[@"-c", cmd];
            NSPipe *pipe = [NSPipe pipe];
            task.standardOutput = pipe;
            task.standardError = pipe;
            [task launch];
            NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
            [task waitUntilExit];
            NSString *outStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";

            dispatch_async(dispatch_get_main_queue(), ^{
                [self appendSignalMessage:outStr type:@"tool_output"];
            });
        });
        return;
    }

    // Agent Autonomous Dispatch
    self.sendActionButton.enabled = NO;
    self.topStatusBadge.stringValue = @"⚡ Ziggy Deliberating & Executing Actions...";

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        self.currentAgentTask = task;

        NSString *home = NSHomeDirectory();
        NSString *ziggyBin = [NSString stringWithFormat:@"%@/.local/bin/ziggy", home];
        if (![[NSFileManager defaultManager] fileExistsAtPath:ziggyBin]) {
            ziggyBin = @"ziggy";
        }

        task.launchPath = @"/bin/zsh";
        NSString *escaped = [text stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        task.arguments = @[@"-c", [NSString stringWithFormat:@"printf \"%%s\\n/exit\\n\" \"%@\" | %@", escaped, ziggyBin]];

        NSPipe *pipe = [NSPipe pipe];
        task.standardOutput = pipe;
        task.standardError = pipe;
        [task launch];
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        [task waitUntilExit];

        NSString *rawOutput = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        self.currentAgentTask = nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            self.sendActionButton.enabled = YES;
            self.topStatusBadge.stringValue = [NSString stringWithFormat:@"Model: %@ • 🧠 max • Context: 1%%", self.activeModelName];
            [self filterAndRenderSignalOutput:rawOutput];
        });
    });
}

- (void)filterAndRenderSignalOutput:(NSString *)raw {
    // Strip metadata bloat, keep pure thoughts and clean answers
    NSArray *lines = [raw componentsSeparatedByString:@"\n"];
    NSMutableString *cleanResponse = [NSMutableString string];
    BOOL inHeader = YES;

    for (NSString *line in lines) {
        if ([line containsString:@"⚡ ZIGAGENT CLI"] || [line containsString:@"Active Provider:"] || [line containsString:@"Agent ID:"] || [line containsString:@"────────────"]) {
            continue;
        }
        if ([line hasPrefix:@">   "]) {
            inHeader = NO;
            continue;
        }
        if ([line containsString:@"Context:"] && [line containsString:@"openai/"]) {
            continue;
        }
        if (line.length > 0) {
            [cleanResponse appendFormat:@"%@\n", line];
        }
    }

    if (cleanResponse.length > 0) {
        [self appendSignalMessage:cleanResponse type:@"agent"];
    }
}

- (void)appendSignalMessage:(NSString *)text type:(NSString *)type {
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineSpacing = 3.0;

    NSColor *fgColor = [NSColor whiteColor];
    NSString *prefix = @"";

    if ([type isEqualToString:@"user"]) {
        fgColor = [NSColor colorWithCalibratedRed:0.00 green:0.95 blue:1.00 alpha:1.0];
        prefix = @"\n╭─ USER ──────────────────────────────────────────────────────────\n│ ";
    } else if ([type isEqualToString:@"agent"]) {
        fgColor = [NSColor colorWithCalibratedWhite:0.92 alpha:1.0];
        prefix = @"\n╭─ ZIGGY ─────────────────────────────────────────────────────────\n";
    } else if ([type isEqualToString:@"tool"]) {
        fgColor = [self aquamarineAccent];
        prefix = @"\n⚡ [ACTION] ";
    } else if ([type isEqualToString:@"tool_output"]) {
        fgColor = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
        prefix = @"";
    } else {
        fgColor = [self bloodstoneOrange];
        prefix = @"\n";
    }

    NSString *formatted = [NSString stringWithFormat:@"%@%@\n", prefix, text];
    NSAttributedString *attr = [[NSAttributedString alloc] initWithString:formatted attributes:@{
        NSForegroundColorAttributeName: fgColor,
        NSFontAttributeName: [self monoFont:12 bold:[type isEqualToString:@"user"]],
        NSParagraphStyleAttributeName: style
    }];

    [self.chatLogTextView.textStorage appendAttributedString:attr];
    [self.chatLogTextView scrollRangeToVisible:NSMakeRange(self.chatLogTextView.string.length, 0)];
}

#pragma mark - Settings Persistence

- (void)loadSettingsFromDisk {
    NSString *home = NSHomeDirectory();
    NSString *cfgPath = [NSString stringWithFormat:@"%@/.ziggy/config.json", home];
    NSData *data = [NSData dataWithContentsOfFile:cfgPath];
    if (data) {
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (dict) {
            NSNumber *unb = dict[@"unbounded_autonomy"];
            if (unb) self.unboundedCheck.state = [unb boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
        }
    }
}

- (void)saveSettingsToDisk {
    NSString *home = NSHomeDirectory();
    NSString *cfgPath = [NSString stringWithFormat:@"%@/.ziggy/config.json", home];
    [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/.ziggy", home] withIntermediateDirectories:YES attributes:nil error:nil];

    NSDictionary *cfgDict = @{
        @"unbounded_autonomy": @(self.unboundedCheck.state == NSControlStateValueOn),
        @"thinking_effort": @"max",
        @"verbosity": @"normal",
        @"active_agent_profile": @"default"
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:cfgDict options:NSJSONWritingPrettyPrinted error:nil];
    if (data) [data writeToFile:cfgPath atomically:YES];

    NSString *selectedModel = [self.modelPopup.selectedItem.title componentsSeparatedByString:@" "].firstObject;
    self.activeModelName = selectedModel;
    self.topStatusBadge.stringValue = [NSString stringWithFormat:@"Model: %@ • 🧠 max • Context: 1%%", selectedModel];

    [self appendSignalMessage:@"✔ Settings successfully applied and persisted to ~/.ziggy/config.json\n" type:@"tool"];
}

#pragma mark - Sessions Table View Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.sessionsList.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSDictionary *item = self.sessionsList[row];
    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"SessionCell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, 44)];
        cell.identifier = @"SessionCell";

        NSTextField *titleLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(6, 20, tableColumn.width - 12, 18)];
        titleLbl.tag = 201;
        titleLbl.font = [self monoFont:11 bold:YES];
        titleLbl.textColor = [NSColor whiteColor];
        titleLbl.bezeled = NO;
        titleLbl.drawsBackground = NO;
        titleLbl.editable = NO;
        [cell addSubview:titleLbl];

        NSTextField *timeLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(6, 4, tableColumn.width - 12, 16)];
        timeLbl.tag = 202;
        timeLbl.font = [self monoFont:9 bold:NO];
        timeLbl.textColor = [NSColor colorWithCalibratedWhite:0.55 alpha:1.0];
        timeLbl.bezeled = NO;
        timeLbl.drawsBackground = NO;
        timeLbl.editable = NO;
        [cell addSubview:timeLbl];
    }

    NSTextField *t = [cell viewWithTag:201];
    NSTextField *s = [cell viewWithTag:202];
    t.stringValue = item[@"title"];
    s.stringValue = item[@"time"];

    return cell;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    return 46.0;
}

- (void)startNewSession {
    [self.sessionsList insertObject:@{
        @"title": [NSString stringWithFormat:@"Session #%lu: Autonomous Goal", self.sessionsList.count + 1],
        @"time": @"Just now",
        @"id": [NSString stringWithFormat:@"ses_%lu", self.sessionsList.count + 100]
    } atIndex:0];
    [self.sessionsTableView reloadData];
    self.chatLogTextView.string = @"";
    [self appendSignalMessage:@"⚡ NEW AUTONOMOUS SESSION STARTED\n• Context memory initialized.\n\n" type:@"system"];
}

- (void)deleteSelectedSession {
    NSInteger row = self.sessionsTableView.selectedRow;
    if (row >= 0 && row < self.sessionsList.count) {
        [self.sessionsList removeObjectAtIndex:row];
        [self.sessionsTableView reloadData];
    } else if (self.sessionsList.count > 0) {
        [self.sessionsList removeLastObject];
        [self.sessionsTableView reloadData];
    }
}

- (void)clearAllSessions {
    [self.sessionsList removeAllObjects];
    [self.sessionsTableView reloadData];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        ZigAgentApp *delegate = [[ZigAgentApp alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
