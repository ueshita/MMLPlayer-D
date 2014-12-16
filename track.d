module mml.track;

import std.stdio, std.math, std.conv;
import mml.tone, mml.envelope, mml.utility, mml.player;

class MMLTrack
{
	ToneGen tone;
	Envelope env;
	MMLCommand[] commands;
	int cmdpos = 0;
	MMLSequencer sequencer;
	int octave = 4;
	int detune = 0;
	int noteShift = 0;
	int noteLength = 4;
	bool noteDot = false;
	int[16] loopSequence;
	int[16] loopCount;
	int loopDepth = 0;
	bool restPeriod = true;
	int gateTimeRatio = 16;
	int gateTimeAbs = 0;
	int waitCount = 0;
	float volume = 1;
	float[2] chvol = [0.71, 0.71];
	bool completed = false;

	this(MMLSequencer sequencer, MMLCommand[] commands) {
		this.sequencer = sequencer;
		this.commands = commands;
		this.tone = new SquareGen(sequencer.sampleRate);
		this.env = new Envelope(sequencer.sampleRate);
		this.env.setADSR(0, 50, 64, 10);
	}
	void reset() {
		this.completed = false;
		this.cmdpos = 0;
		this.waitCount = 0;
	}
	void processMML() {
		while (this.waitCount == 0 && this.cmdpos < this.commands.length) {
			MMLCommand cmd = this.commands[this.cmdpos++];
			if (cmd.code >= 'a' && cmd.code <= 'g') {
				// 音符
				this.tone.scale = this.noteToScale(cmd.code, cmd.args[0]) + this.detune * 0.01f;
				this.restPeriod = false;
				this.waitCount = this.lengthToCount(cmd.args[1], cmd.args[2] != 0);

				this.env.setLength(this.waitCount * this.gateTimeRatio / 16);
				if (this.env.autoKeyOff) {
					this.tone.reset();
					this.env.keyOn();
				}
				if (this.cmdpos < this.commands.length && this.commands[this.cmdpos].code == '&') {
					this.cmdpos++;
					this.env.autoKeyOff = false;
				} else {
					this.env.autoKeyOff = true;
				}
			} else if (cmd.code == 'r') {
				// 休符
				this.restPeriod = true;
				this.waitCount = this.lengthToCount(cmd.args[1], cmd.args[2] != 0);
			} else if (cmd.code == 't') {
				// テンポ
				if (cmd.args[0] <= 0) {
					writeln("tempo error.");
					continue;
				}
				this.sequencer.tempo = cmd.args[0];
			} else if (cmd.code == 'l') {
				// デフォルト音長
				if (cmd.args[1] <= 0) {
					writeln("length error.");
					continue;
				}
				this.noteLength = cmd.args[1];
				this.noteDot = cmd.args[2] != 0;
			} else if (cmd.code == 'v') {
				// ボリューム
				this.volume = cmd.args[0] / 15.0f;
			} else if (cmd.code == 'q') {
				// ゲートタイム(比率)
				this.gateTimeRatio = cmd.args[0];
			} else if (cmd.code == 'o') {
				// オクターブ
				this.octave = cmd.args[0];
			} else if (cmd.code == '>') {
				// オクターブ-
				this.octave += (this.sequencer.option.octaveReverse) ? +1 : -1;
			} else if (cmd.code == '<') {
				// オクターブ+
				this.octave += (this.sequencer.option.octaveReverse) ? -1 : +1;
			} else if (cmd.code == '[') {
				// ループ開始
				this.loopSequence[this.loopDepth] = this.cmdpos;
				this.loopCount[this.loopDepth] = cmd.args[0];
				this.loopDepth++;
			} else if (cmd.code == '|') {
				// ループ中断
				if (this.loopDepth <= 0) {
					writeln("loop continue error.");
					continue;
				}
				if (this.loopCount[this.loopDepth - 1] > 1) {
					this.loopCount[this.loopDepth - 1]--;
					this.cmdpos = this.loopSequence[this.loopDepth - 1];
				}
			} else if (cmd.code == ']') {
				// ループ終了
				if (this.loopDepth <= 0) {
					writeln("loop end error.");
					continue;
				}
				if (--this.loopCount[this.loopDepth - 1] > 0) {
					this.cmdpos = this.loopSequence[this.loopDepth - 1];
				} else {
					this.loopDepth--;
				}
			} else if (cmd.code == '@') {
				if (cmd.subcode == 0) {
					// 音色変更
					switch (cmd.args[0]) {
						case 0: this.tone = new SineGen(this.sequencer.sampleRate);			break;
						case 1: this.tone = new SawtoothGen(this.sequencer.sampleRate);		break;
						case 2: this.tone = new TriangleGen(this.sequencer.sampleRate);		break;
						case 3: this.tone = new SquareGen(this.sequencer.sampleRate);		break;
						case 4: this.tone = new WhiteNoiseGen(this.sequencer.sampleRate);	break;
						case 5: this.tone = new SquareGen(this.sequencer.sampleRate);		break;
						case 6: this.tone = new TriangleGen(this.sequencer.sampleRate);		break;
						case 7: this.tone = new WhiteNoiseGen(this.sequencer.sampleRate);	break;
						case 8: this.tone = new WhiteNoiseGen(this.sequencer.sampleRate);	break;
						default: break;
					}
				} else if (cmd.subcode == 'w') {
					// デューティー比
					this.tone.dutyRatio = cmd.args[0] * 0.01f;
				} else if (cmd.subcode == 'e') {
					// エンベロープ
					if (cmd.args[0] == 1) {
						this.env.setADSR(cmd.args[1], cmd.args[2], cmd.args[3], cmd.args[4]);
					}
				} else if (cmd.subcode == 'p') {
					// パン(定位)
					int ipan = cmd.args[0] - 64;
					float fpan = (ipan < 0) ? ipan / 64.0f : ipan / 63.0f;
					this.chvol[0] = cos((fpan + 1) / 4 * PI);
					this.chvol[1] = sin((fpan + 1) / 4 * PI);
				} else if (cmd.subcode == 'q') {
					// ゲートタイム(絶対)
					this.gateTimeAbs = cmd.args[0];
				} else if (cmd.subcode == 'd') {
					// デチューン(セント)
					this.detune = cmd.args[0];
				} else {
					writefln("Not support [@%c] %s", cast(char)cmd.subcode, cmd.args.to!string());
				}
			} else if (cmd.code == '^') {
				// ノートシフト
				if (cmd.args[0]) {
					this.noteShift += cmd.args[1];
				} else {
					this.noteShift = cmd.args[1];
				}
			} else {
				writefln("Not support [%c] %s", cast(char)cmd.code, cmd.args.to!string());
			}
		}
	}
	// 音長をカウントに変換
	int lengthToCount(int length, bool dot) {
		if (length == 0) {
			length = this.noteLength;
			dot = this.noteDot;
		}
		const int beats = 4;
		int s = this.sequencer.sampleRate * beats * 60;
		if (dot) s *= 1.5f;
		return s / this.sequencer.tempo / length;
	}
	// 音符を音階に変換
	int noteToScale(int note, int acci) {
		int scale = 0;
		switch (note) {
			case 'c': scale = 3;  break;
			case 'd': scale = 5;  break;
			case 'e': scale = 7;  break;
			case 'f': scale = 8;  break;
			case 'g': scale = 10; break;
			case 'a': scale = 12; break;
			case 'b': scale = 14; break;
			default: return 0;
		}
		scale += this.noteShift;
		return scale + (this.octave - 4) * 12 + acci;
	}
	FrameData synth() {
		FrameData frame;
		if (this.waitCount > 0) {
			this.waitCount--;
			if (!this.restPeriod) {
				float s = this.volume * this.env.gen() * this.tone.gen();
				frame.data[0] = s * this.chvol[0];
				frame.data[1] = s * this.chvol[1];
				return frame;
			}
		} else {
			if (this.cmdpos < this.commands.length) {
				this.processMML();
			} else {
				this.completed = true;
			}
		}
		return frame;
	}
}