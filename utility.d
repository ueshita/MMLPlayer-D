module mml.utility;

import std.stdio, std.string, std.array, std.regex, std.math, std.conv;
import mml.track;

struct MMLCommand
{
	char code;
	char subcode;
	short[8] args;
}

struct MMLOption
{
	bool octaveReverse = false;
	bool velocityReverse = false;
}

class MMLSequencer
{
	int sampleRate;
	int tempo = 120;
	MMLOption option;

	this(int sampleRate) {
		this.sampleRate = sampleRate;
	}
}

MMLCommand[][] parseMML(string mml, out MMLOption option)
{
	// 1文字覗く
	char peekCode(string str, int index) {
		char result = '\0';
		if (index < str.length) {
			result = str[index];
		}
		return result;
	}
	// 数値の読み取り
	short readNumber(string str, ref int index) {
		short result = 0;
		while (index < str.length) {
			char c = str[index];
			if (c >= '0' && c <= '9') {
				result = cast(short)(result * 10 + c - '0');
				index++;
			} else {
				break;
			}
		}
		return result;
	}
	// 変化記号の読み取り
	short readAccidental(string str, ref int index) {
		short result = 0;
		if (index < str.length) {
			char c = str[index];
			if (c == '+' || c == '#') {
				result = 1;
				index++;
			} else if (c == '-') {
				result = -1;
				index++;
			}
		}
		return result;
	}
	// 付点音符の読み取り
	short readDottedNote(string str, ref int index) {
		short result = 0;
		if (index < str.length) {
			char c = str[index];
			if (c == '.') {
				result = 1;
				index++;
			}
		}
		return result;
	}

	// 小文字に変換
	mml = mml.toLower();
	// コメントを除去
	while (1) {
		int ib = mml.indexOf("/*");
		if (ib < 0) break;
		int ie = mml[ib + 2 .. $].indexOf("*/");
		if (ie < 0) ie = mml.length;
		ie += ib + 4;
		mml = mml[0 .. ib] ~ mml[ie .. $];
	}
	// 全角スペースを除去
	mml = mml.replace(regex(r"　", "gm"), "");

	// #マクロの処理
	foreach (line; mml.splitLines()) {
		line = line.strip();
		if (line.length > 2 && line[0] == '#') {
			switch (line) {
				case "#octave reverse":
					option.octaveReverse = true;
					break;
				case "velocity reverse":
					option.velocityReverse = true;
					break;
				default:
					break;
			}
			mml = mml.replace(line, "");
		}
	}
	// スペースとタブと改行を除去
	mml = mml.removechars(" \t\n\r");

	// $マクロの処理
	while (1) {
		auto m = mml.match(regex(r"\$.*?=.*?;"));
		if (!m) break;
		mml = mml.replace(m.hit, "");
		string[] tokens = m.hit.split(regex("="));
		if (tokens.length == 2) {
			string symbol = tokens[0].strip();
			string statements = tokens[1][0 .. $ - 1].strip();
			int argsBegin = symbol.indexOf("{");
			if (argsBegin > 0) {
				string[] args = symbol[argsBegin + 1 .. $ - 1].split(regex(","));
				symbol = symbol[0 .. argsBegin].strip();
				while (1) {
					auto repm = mml.match(regex(r"\" ~ symbol ~ r"\{.*?\}", "g"));
					if (!repm) break;
					string target = repm.hit;
					argsBegin = target.indexOf("{");
					string[] targetArgs = target[argsBegin + 1 .. $ - 1].split(regex(","));
					string copy = statements;
					for (int i = 0; i < args.length; i++) {
						copy = copy.replace("%" ~ args[i], targetArgs[i]);
					}
					mml = mml.replace(target, copy);
				}
			} else {
				mml = mml.replace(symbol, statements);
			}
		}
	}

	// トラックに分割
	string[] trackStrList = mml.split(";");
	
	MMLCommand[][] tracks;
	tracks.length = trackStrList.length;
	
	foreach (int i, trackStr; trackStrList) {
		tracks[i] = [];
		
		int index = 0;
		while (index < trackStr.length) {
			char code = trackStr[index++];
			char subcode = 0;
			short args[8];
			if ((code >= 'a' && code <= 'g') || code == 'r' || code == 'l') {
				args[0] = readAccidental(trackStr, index);
				args[1] = readNumber(trackStr, index);
				args[2] = readDottedNote(trackStr, index);
			} else if (code == '/' && peekCode(trackStr, index) == ':') {
				index++;
				code = '[';
				args[0] = readNumber(trackStr, index);
				if (args[0] == 0) args[0] = 2;
			} else if (code == '/') {
				code = '|';
			} else if (code == ':' && peekCode(trackStr, index) == '/') {
				index++;
				code = ']';
			} else if (code == 'n' && peekCode(trackStr, index) == 's') {
				index++;
				code = '^';
				args[0] = 0;
				args[1] = readAccidental(trackStr, index);
				args[1] *= readNumber(trackStr, index);
			} else if (code == '@') {
				char next = peekCode(trackStr, index);
				if (next >= '0' && next <= '9') {
					args[0] = readNumber(trackStr, index);
				} else if (next == 'n' && peekCode(trackStr, index) == 's') {
					index++;
					code = '^';
					args[0] = 1;
					if (readAccidental(trackStr, index) < 0) {
						args[1] = -readNumber(trackStr, index);
					} else {
						args[1] = readNumber(trackStr, index);
					}
				} else if (next == 'd') {
					index++;
					subcode = next;
					if (readAccidental(trackStr, index) < 0) {
						args[0] = -readNumber(trackStr, index);
					} else {
						args[0] = readNumber(trackStr, index);
					}
				} else {
					index++;
					subcode = next;
					for (int j = 0; ; j++) {
						int preindex = index;
						short value = readNumber(trackStr, index);
						if (index <= preindex) break;
						if (j < 8) args[j] = value;
						if (peekCode(trackStr, index) == ',') index++;
					}
				}
			} else {
				args[0] = readNumber(trackStr, index);
			}
			if (code > 0) {
				tracks[i] ~= MMLCommand(code, subcode, args);
			}
		}
	}
	return tracks;
}