package logger

import (
	"os"
	"time"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var Logger *zap.Logger
var currentLogLevel zapcore.Level

func InitLogger() {
	config := zapcore.EncoderConfig{
		TimeKey:        "time",
		LevelKey:       "level",
		MessageKey:     "msg",
		CallerKey:      "caller",
		NameKey:        "logger",
		StacktraceKey:  "stacktrace",
		LineEnding:     zapcore.DefaultLineEnding,
		EncodeLevel:    customLevelEncoder,
		EncodeTime:     customTimeEncoder,
		EncodeDuration: zapcore.StringDurationEncoder,
		EncodeCaller:   customCallerEncoder,
		EncodeName:     zapcore.FullNameEncoder,
	}

	core := zapcore.NewCore(
		zapcore.NewConsoleEncoder(config),
		zapcore.AddSync(os.Stdout),
		zapcore.DebugLevel,
	)

	Logger = zap.New(core, zap.AddCallerSkip(1), zap.Hooks(levelHook))
}

const (
	colorReset  = "\033[0m"
	colorRed    = "\033[31m"
	colorGreen  = "\033[32m"
	colorYellow = "\033[33m"
	colorBlue   = "\033[34m"
	colorCyan   = "\033[36m"
)

func levelHook(entry zapcore.Entry) error {
	currentLogLevel = entry.Level
	return nil
}

func customTimeEncoder(t time.Time, enc zapcore.PrimitiveArrayEncoder) {
	var timeColor string
	switch currentLogLevel {
	case zapcore.ErrorLevel:
		timeColor = colorRed
	case zapcore.WarnLevel:
		timeColor = colorYellow
	case zapcore.InfoLevel:
		timeColor = colorBlue
	case zapcore.DebugLevel:
		timeColor = colorGreen
	default:
		timeColor = colorBlue
	}

	timeStr := timeColor + "[" + t.Format("2006-01-02 15:04:05") + "]" + colorReset
	enc.AppendString(timeStr)
}

func SyncLogger() {
	_ = Logger.Sync()
}

func customLevelEncoder(level zapcore.Level, enc zapcore.PrimitiveArrayEncoder) {
	var levelStr string
	switch level {
	case zapcore.InfoLevel:
		levelStr = colorBlue + "[" + level.CapitalString() + "]" + colorReset
	case zapcore.WarnLevel:
		levelStr = colorYellow + "[" + level.CapitalString() + "]" + colorReset
	case zapcore.ErrorLevel:
		levelStr = colorRed + "[" + level.CapitalString() + "]" + colorReset
	case zapcore.DebugLevel:
		levelStr = colorGreen + "[" + level.CapitalString() + "]" + colorReset
	default:
		levelStr = "[" + level.CapitalString() + "]"
	}

	enc.AppendString(levelStr)
}

func customCallerEncoder(caller zapcore.EntryCaller, enc zapcore.PrimitiveArrayEncoder) {
	if Logger.Core().Enabled(zapcore.DebugLevel) {
		const colorDim = "\033[2m"
		const colorReset = "\033[0m"
		callerStr := colorDim + padRight(caller.TrimmedPath(), 30) + colorReset
		enc.AppendString(callerStr)
	}
}

func padRight(str string, length int) string {
	if len(str) >= length {
		return str
	}
	padding := length - len(str)
	padded := str
	for i := 0; i < padding; i++ {
		padded += " "
	}
	return padded
}
