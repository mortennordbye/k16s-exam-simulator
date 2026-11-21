package main

import (
	"database/sql"
	"log"
	"os"
	"path/filepath"
	"time"

	_ "modernc.org/sqlite"
)

type Session struct {
	ID           string              `json:"id"`
	Profile      string              `json:"profile"`
	StartedAt    time.Time           `json:"started_at"`
	EndedAt      *time.Time          `json:"ended_at,omitempty"`
	DurationSecs int                 `json:"duration_secs"`
	ExamMode     bool                `json:"exam_mode"`
	GradedAt     *time.Time          `json:"graded_at,omitempty"`
	Progress     map[string]Progress `json:"progress"`
}

type Progress struct {
	Status       string     `json:"status"` // preparing|ready|attempted|passed|partial|failed
	CheckedAt    *time.Time `json:"checked_at,omitempty"`
	Output       string     `json:"output,omitempty"`
	ChecksPassed int        `json:"checks_passed"`
	ChecksTotal  int        `json:"checks_total"`
}

func mustOpenDB(path string) *sql.DB {
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		log.Fatalf("create db dir: %v", err)
	}
	db, err := sql.Open("sqlite", path)
	if err != nil {
		log.Fatalf("open db: %v", err)
	}
	db.SetMaxOpenConns(1)
	if _, err := db.Exec(`PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;`); err != nil {
		log.Fatalf("db pragma: %v", err)
	}
	if _, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS sessions (
			id            TEXT PRIMARY KEY,
			profile       TEXT NOT NULL,
			started_at    INTEGER NOT NULL,
			ended_at      INTEGER,
			duration_secs INTEGER NOT NULL DEFAULT 7200
		);
		CREATE TABLE IF NOT EXISTS progress (
			session_id  TEXT NOT NULL,
			question_id TEXT NOT NULL,
			status      TEXT NOT NULL,
			checked_at  INTEGER NOT NULL,
			output      TEXT,
			PRIMARY KEY (session_id, question_id),
			FOREIGN KEY (session_id) REFERENCES sessions(id)
		);
	`); err != nil {
		log.Fatalf("init schema: %v", err)
	}
	// CKS hub columns. ALTER fails with "duplicate column" once added; ignore.
	for _, stmt := range []string{
		`ALTER TABLE sessions ADD COLUMN exam_mode INTEGER NOT NULL DEFAULT 0`,
		`ALTER TABLE sessions ADD COLUMN graded_at INTEGER`,
		`ALTER TABLE progress ADD COLUMN checks_passed INTEGER NOT NULL DEFAULT 0`,
		`ALTER TABLE progress ADD COLUMN checks_total INTEGER NOT NULL DEFAULT 0`,
	} {
		db.Exec(stmt)
	}
	return db
}

func createSession(db *sql.DB, id, profile string, durationSecs int, examMode bool) error {
	_, err := db.Exec(
		`INSERT INTO sessions (id, profile, started_at, duration_secs, exam_mode) VALUES (?, ?, ?, ?, ?)`,
		id, profile, time.Now().Unix(), durationSecs, examMode,
	)
	return err
}

func getLastSession(db *sql.DB) (*Session, error) {
	row := db.QueryRow(
		`SELECT id, profile, started_at, ended_at, duration_secs, exam_mode, graded_at FROM sessions
		 ORDER BY started_at DESC LIMIT 1`,
	)
	return scanSession(db, row)
}

func setGraded(db *sql.DB, id string) error {
	_, err := db.Exec(`UPDATE sessions SET graded_at = ? WHERE id = ?`, time.Now().Unix(), id)
	return err
}

func getActiveSession(db *sql.DB) (*Session, error) {
	row := db.QueryRow(
		`SELECT id, profile, started_at, ended_at, duration_secs, exam_mode, graded_at FROM sessions
		 WHERE ended_at IS NULL ORDER BY started_at DESC LIMIT 1`,
	)
	return scanSession(db, row)
}

func getSession(db *sql.DB, id string) (*Session, error) {
	row := db.QueryRow(
		`SELECT id, profile, started_at, ended_at, duration_secs, exam_mode, graded_at FROM sessions WHERE id = ?`, id,
	)
	return scanSession(db, row)
}

func scanSession(db *sql.DB, row *sql.Row) (*Session, error) {
	var s Session
	var startedAt int64
	var endedAt, gradedAt sql.NullInt64
	if err := row.Scan(&s.ID, &s.Profile, &startedAt, &endedAt, &s.DurationSecs, &s.ExamMode, &gradedAt); err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	s.StartedAt = time.Unix(startedAt, 0)
	if endedAt.Valid {
		t := time.Unix(endedAt.Int64, 0)
		s.EndedAt = &t
	}
	if gradedAt.Valid {
		g := time.Unix(gradedAt.Int64, 0)
		s.GradedAt = &g
	}
	progress, err := getProgress(db, s.ID)
	if err != nil {
		return nil, err
	}
	s.Progress = progress
	return &s, nil
}

func endSession(db *sql.DB, id string) error {
	_, err := db.Exec(`UPDATE sessions SET ended_at = ? WHERE id = ?`, time.Now().Unix(), id)
	return err
}

func getProgress(db *sql.DB, sessionID string) (map[string]Progress, error) {
	rows, err := db.Query(
		`SELECT question_id, status, checked_at, output, checks_passed, checks_total FROM progress WHERE session_id = ?`, sessionID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := map[string]Progress{}
	for rows.Next() {
		var p Progress
		var qid string
		var checkedAt int64
		var output sql.NullString
		if err := rows.Scan(&qid, &p.Status, &checkedAt, &output, &p.ChecksPassed, &p.ChecksTotal); err != nil {
			return nil, err
		}
		t := time.Unix(checkedAt, 0)
		p.CheckedAt = &t
		if output.Valid {
			p.Output = output.String
		}
		result[qid] = p
	}
	return result, rows.Err()
}

func upsertProgress(db *sql.DB, sessionID, questionID, status, output string) error {
	return upsertProgressScore(db, sessionID, questionID, status, output, 0, 0)
}

func upsertProgressScore(db *sql.DB, sessionID, questionID, status, output string, passed, total int) error {
	_, err := db.Exec(`
		INSERT INTO progress (session_id, question_id, status, checked_at, output, checks_passed, checks_total)
		VALUES (?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT (session_id, question_id) DO UPDATE SET
			status        = excluded.status,
			checked_at    = excluded.checked_at,
			output        = excluded.output,
			checks_passed = excluded.checks_passed,
			checks_total  = excluded.checks_total
	`, sessionID, questionID, status, time.Now().Unix(), output, passed, total)
	return err
}
