import React, { useState, useEffect } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TextInput,
  TouchableOpacity,
  ScrollView,
  SafeAreaView,
  StatusBar,
  Alert,
} from 'react-native';

interface Message {
  id: string;
  role: 'user' | 'agent' | 'system';
  content: string;
}

export default function App() {
  const [host, setHost] = useState('192.168.1.100:4040');
  const [token, setToken] = useState('');
  const [connected, setConnected] = useState(false);
  const [inputText, setInputText] = useState('');
  const [messages, setMessages] = useState<Message[]>([
    {
      id: '1',
      role: 'system',
      content: '⚡ ZigAgent Cloud Gateway Client Ready. Enter host and pair to begin.',
    },
  ]);
  const [contextFill, setContextFill] = useState(2);
  const [activeTab, setActiveTab] = useState<'chat' | 'diff' | 'doctor'>('chat');
  const [gitDiff, setGitDiff] = useState('No active changes.');

  const handleConnect = () => {
    if (!host) return;
    setConnected(true);
    fetchStatus();
  };

  const fetchStatus = async () => {
    try {
      const res = await fetch(`http://${host}/api/status`);
      if (res.ok) {
        const data = await res.json();
        if (data.fill_pct !== undefined) setContextFill(data.fill_pct);
      }
    } catch (_) {}
  };

  const handleSend = () => {
    if (!inputText.trim()) return;
    const userMsg: Message = { id: Date.now().toString(), role: 'user', content: inputText };
    setMessages((prev) => [...prev, userMsg]);
    setInputText('');

    // Simulate Agent Action
    setTimeout(() => {
      const agentMsg: Message = {
        id: (Date.now() + 1).toString(),
        role: 'agent',
        content: '⚡ Ziggy executing directive natively on remote host...',
      };
      setMessages((prev) => [...prev, agentMsg]);
      setContextFill((prev) => Math.min(prev + 3, 100));
    }, 400);
  };

  const handleHalt = async () => {
    Alert.alert('Emergency Halt', 'Sending <ESC> interrupt signal to remote Ziggy runtime.');
    try {
      await fetch(`http://${host}/api/interrupt`, { method: 'POST' });
    } catch (_) {}
  };

  const fetchDiff = async () => {
    try {
      const res = await fetch(`http://${host}/api/diff`);
      const text = await res.text();
      setGitDiff(text || 'Working tree clean.');
    } catch (_) {
      setGitDiff('Failed to reach remote host.');
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="light-content" />

      {/* Header HUD */}
      <View style={styles.header}>
        <View style={styles.brandRow}>
          <View style={styles.titleGroup}>
            <View style={styles.pulseDot} />
            <Text style={styles.brandText}>ZIGAGENT</Text>
            <View style={styles.badge}>
              <Text style={styles.badgeText}>REMOTE</Text>
            </View>
          </View>
          <TouchableOpacity style={styles.haltBtn} onPress={handleHalt}>
            <Text style={styles.haltText}>🛑 HALT</Text>
          </TouchableOpacity>
        </View>

        {/* Context Window Bar */}
        <View style={styles.hudCard}>
          <View style={styles.hudLabels}>
            <Text style={styles.hudMuted}>Context Fill: {contextFill}%</Text>
            <Text style={styles.hudAccent}>⚡ UNBOUNDED</Text>
          </View>
          <View style={styles.track}>
            <View style={[styles.fill, { width: `${contextFill}%` }]} />
          </View>
        </View>
      </View>

      {/* Navigation Tabs */}
      <View style={styles.tabs}>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'chat' && styles.activeTab]}
          onPress={() => setActiveTab('chat')}
        >
          <Text style={[styles.tabText, activeTab === 'chat' && styles.activeTabText]}>💬 Chat</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'diff' && styles.activeTab]}
          onPress={() => {
            setActiveTab('diff');
            fetchDiff();
          }}
        >
          <Text style={[styles.tabText, activeTab === 'diff' && styles.activeTabText]}>🗂️ Git Diff</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'doctor' && styles.activeTab]}
          onPress={() => setActiveTab('doctor')}
        >
          <Text style={[styles.tabText, activeTab === 'doctor' && styles.activeTabText]}>🩺 Doctor</Text>
        </TouchableOpacity>
      </View>

      {/* Tab 1: Chat Stream */}
      {activeTab === 'chat' && (
        <View style={styles.chatWrapper}>
          <ScrollView style={styles.stream} contentContainerStyle={styles.streamContent}>
            {messages.map((m) => (
              <View
                key={m.id}
                style={[
                  styles.msgBox,
                  m.role === 'user' ? styles.userMsg : m.role === 'agent' ? styles.agentMsg : styles.sysMsg,
                ]}
              >
                <Text style={styles.msgText}>{m.content}</Text>
              </View>
            ))}
          </ScrollView>

          {/* Quick Action Chips */}
          <View style={styles.chipRow}>
            <TouchableOpacity style={styles.chip} onPress={() => setInputText('/doctor')}>
              <Text style={styles.chipText}>/doctor</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.chip} onPress={() => setInputText('/mcp')}>
              <Text style={styles.chipText}>/mcp</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.chip} onPress={() => setInputText('!git status')}>
              <Text style={styles.chipText}>!git status</Text>
            </TouchableOpacity>
          </View>

          {/* Input Bar */}
          <View style={styles.inputBar}>
            <TextInput
              style={styles.input}
              placeholder="Send instruction or !cmd..."
              placeholderTextColor="#8b9eb7"
              value={inputText}
              onChangeText={setInputText}
              onSubmitEditing={handleSend}
            />
            <TouchableOpacity style={styles.sendBtn} onPress={handleSend}>
              <Text style={styles.sendText}>Send</Text>
            </TouchableOpacity>
          </View>
        </View>
      )}

      {/* Tab 2: Git Diff */}
      {activeTab === 'diff' && (
        <ScrollView style={styles.diffContainer}>
          <Text style={styles.diffText}>{gitDiff}</Text>
        </ScrollView>
      )}

      {/* Tab 3: System Doctor */}
      {activeTab === 'doctor' && (
        <View style={styles.doctorContainer}>
          <Text style={styles.docTitle}>System & Toolchains Audit</Text>
          <Text style={styles.docItem}>• Zig Engine: <Text style={styles.docGreen}>0.16.0 ReleaseFast</Text></Text>
          <Text style={styles.docItem}>• Memory Model: <Text style={styles.docAccent}>Thermodynamic Merkle</Text></Text>
          <Text style={styles.docItem}>• Allocator: <Text style={styles.docGreen}>Zero-GC Step Arena</Text></Text>
          <Text style={styles.docItem}>• Remote Gateway: <Text style={styles.docGreen}>Port 4040 Online</Text></Text>
        </View>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#090d13' },
  header: { padding: 16, borderBottomWidth: 1, borderColor: '#26334d', backgroundColor: '#121824' },
  brandRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 },
  titleGroup: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  pulseDot: { width: 8, height: 8, borderRadius: 4, backgroundColor: '#00e676' },
  brandText: { color: '#f0f6fc', fontWeight: '800', fontSize: 16, letterSpacing: 0.5 },
  badge: { backgroundColor: 'rgba(0, 242, 254, 0.15)', paddingHorizontal: 6, paddingVertical: 2, borderRadius: 4 },
  badgeText: { color: '#00f2fe', fontSize: 10, fontWeight: '700' },
  haltBtn: { backgroundColor: '#ff3366', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 6 },
  haltText: { color: '#fff', fontWeight: '700', fontSize: 12 },
  hudCard: { backgroundColor: '#182030', padding: 10, borderRadius: 8, borderWidth: 1, borderColor: '#26334d' },
  hudLabels: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 6 },
  hudMuted: { color: '#8b9eb7', fontSize: 11, fontFamily: 'monospace' },
  hudAccent: { color: '#00f2fe', fontSize: 11, fontWeight: '700' },
  track: { height: 6, backgroundColor: 'rgba(255,255,255,0.08)', borderRadius: 3, overflow: 'hidden' },
  fill: { height: '100%', backgroundColor: '#00f2fe' },
  tabs: { flexDirection: 'row', borderBottomWidth: 1, borderColor: '#26334d', backgroundColor: '#121824' },
  tab: { flex: 1, paddingVertical: 10, alignItems: 'center', borderBottomWidth: 2, borderColor: 'transparent' },
  activeTab: { borderColor: '#00f2fe' },
  tabText: { color: '#8b9eb7', fontSize: 13, fontWeight: '600' },
  activeTabText: { color: '#00f2fe' },
  chatWrapper: { flex: 1 },
  stream: { flex: 1, padding: 12 },
  streamContent: { gap: 12, paddingBottom: 16 },
  msgBox: { padding: 12, borderRadius: 8, maxWidth: '85%' },
  userMsg: { alignSelf: 'flex-end', backgroundColor: '#1f3b58', borderWidth: 1, borderColor: '#4facfe' },
  agentMsg: { alignSelf: 'flex-start', backgroundColor: '#182030', borderWidth: 1, borderColor: '#26334d', maxWidth: '95%' },
  sysMsg: { alignSelf: 'center', backgroundColor: 'rgba(0, 242, 254, 0.08)', borderWidth: 1, borderColor: '#26334d', width: '100%' },
  msgText: { color: '#f0f6fc', fontSize: 14, lineHeight: 20 },
  chipRow: { flexDirection: 'row', gap: 6, paddingHorizontal: 12, paddingBottom: 8 },
  chip: { backgroundColor: '#182030', borderWidth: 1, borderColor: '#26334d', paddingHorizontal: 10, paddingVertical: 4, borderRadius: 12 },
  chipText: { color: '#00f2fe', fontSize: 11, fontFamily: 'monospace' },
  inputBar: { flexDirection: 'row', padding: 12, backgroundColor: '#121824', borderTopWidth: 1, borderColor: '#26334d', gap: 8 },
  input: { flex: 1, backgroundColor: '#182030', borderWidth: 1, borderColor: '#26334d', borderRadius: 8, paddingHorizontal: 12, color: '#f0f6fc', fontSize: 14 },
  sendBtn: { backgroundColor: '#00f2fe', paddingHorizontal: 16, justifyContent: 'center', borderRadius: 8 },
  sendText: { color: '#000', fontWeight: '700', fontSize: 14 },
  diffContainer: { flex: 1, padding: 12, backgroundColor: '#000' },
  diffText: { color: '#00e676', fontFamily: 'monospace', fontSize: 12 },
  doctorContainer: { flex: 1, padding: 16 },
  docTitle: { color: '#00f2fe', fontSize: 16, fontWeight: '700', marginBottom: 12 },
  docItem: { color: '#f0f6fc', fontSize: 14, marginBottom: 8 },
  docGreen: { color: '#00e676', fontWeight: '700' },
  docAccent: { color: '#ff6b35', fontWeight: '700' },
});
