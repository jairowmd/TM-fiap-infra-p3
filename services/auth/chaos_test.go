package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestChaosMiddleware(t *testing.T) {
	app := &App{}
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	handler := app.chaosMiddleware(next)

	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/validate", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("sem falha: esperado 200, recebido %d", rec.Code)
	}

	app.Failing.Store(true)
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/validate", nil))
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("com falha: esperado 500, recebido %d", rec.Code)
	}
}

func TestChaosHandler(t *testing.T) {
	app := &App{}

	cases := []struct {
		method  string
		code    int
		failing bool
	}{
		{http.MethodPost, http.StatusOK, true},
		{http.MethodGet, http.StatusOK, true},
		{http.MethodDelete, http.StatusOK, false},
		{http.MethodPut, http.StatusMethodNotAllowed, false},
	}

	for _, c := range cases {
		rec := httptest.NewRecorder()
		app.chaosHandler(rec, httptest.NewRequest(c.method, "/admin/chaos", nil))
		if rec.Code != c.code {
			t.Fatalf("%s: esperado %d, recebido %d", c.method, c.code, rec.Code)
		}
		if app.Failing.Load() != c.failing {
			t.Fatalf("%s: esperado failing=%v", c.method, c.failing)
		}
	}
}
