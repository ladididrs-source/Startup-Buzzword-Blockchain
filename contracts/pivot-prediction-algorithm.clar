;; title: pivot-prediction-algorithm
;; version: 1.0.0
;; summary: Record project signals and suggest pivots when the running average drops below a threshold.
;; description: Self-contained, no cross-contract calls, uses cumulative sums and counts for averages.

;; -----------------------------------------------------------------------------
;; constants and error codes
;; -----------------------------------------------------------------------------

(define-constant ERR-PROJECT-NOT-FOUND (err u200))
(define-constant ERR-NOT-OWNER (err u201))
(define-constant ERR-BAD-NAME (err u202))
(define-constant ERR-BAD-SCORE (err u203))
(define-constant ERR-PAUSED (err u204))

(define-constant MAX-NAME-LEN u64)
(define-constant MIN-SCORE -100)
(define-constant MAX-SCORE 100)

;; -----------------------------------------------------------------------------
;; data vars
;; -----------------------------------------------------------------------------

(define-data-var next-project-id uint u1)

;; -----------------------------------------------------------------------------
;; data maps
;; -----------------------------------------------------------------------------

;; per-project metadata
(define-map projects
  { id: uint }
  { owner: principal,
    name: (string-ascii 64),
    created-at: uint,
    threshold: int,
    sum: int,
    count: uint,
    paused: bool })

;; store last sequence per project
(define-map project-seq
  { id: uint }
  { seq: uint })

;; per-signal storage (append-only)
(define-map signals
  { project-id: uint, seq: uint }
  { score: int,
    at: uint })

;; -----------------------------------------------------------------------------
;; private helpers
;; -----------------------------------------------------------------------------

(define-private (project-exists (id uint))
  (is-some (map-get? projects { id: id })))

(define-private (only-owner (id uint))
  (let ((row (map-get? projects { id: id })))
    (match row p
      (begin
        (if (is-eq (get owner p) tx-sender) (ok true) ERR-NOT-OWNER))
      ERR-PROJECT-NOT-FOUND)))

(define-private (ensure-active (id uint))
  (let ((row (map-get? projects { id: id })))
    (match row p
      (if (is-eq (get paused p) false)
          (ok true)
          ERR-PAUSED)
      ERR-PROJECT-NOT-FOUND)))

(define-private (bounded-score (s int))
  (if (and (>= s MIN-SCORE) (<= s MAX-SCORE)) (ok s) ERR-BAD-SCORE))

;; -----------------------------------------------------------------------------
;; public functions
;; -----------------------------------------------------------------------------

(define-public (register-project (name (string-ascii 64)))
  (if (is-eq name "")
      ERR-BAD-NAME
      (let ((id (var-get next-project-id))
            (now u0))
        (map-insert projects { id: id }
          { owner: tx-sender,
            name: name,
            created-at: now,
            threshold: 0,
            sum: 0,
            count: u0,
            paused: false })
        (map-insert project-seq { id: id } { seq: u0 })
        (var-set next-project-id (+ id u1))
        (ok id))))

(define-public (set-threshold (project-id uint) (new-threshold int))
  (begin
    (try! (only-owner project-id))
    (let ((row (map-get? projects { id: project-id })))
      (match row p
        (begin
(map-set projects { id: project-id }
            { owner: (get owner p),
              name: (get name p),
              created-at: (get created-at p),
              threshold: new-threshold,
              sum: (get sum p),
              count: (get count p),
              paused: (get paused p) })
          (ok true))
        ERR-PROJECT-NOT-FOUND))))

(define-public (pause (project-id uint))
  (begin
    (try! (only-owner project-id))
    (let ((row (map-get? projects { id: project-id })))
      (match row p
        (begin
(map-set projects { id: project-id }
            { owner: (get owner p),
              name: (get name p),
              created-at: (get created-at p),
              threshold: (get threshold p),
              sum: (get sum p),
              count: (get count p),
              paused: true })
          (ok true))
        ERR-PROJECT-NOT-FOUND))))

(define-public (unpause (project-id uint))
  (begin
    (try! (only-owner project-id))
    (let ((row (map-get? projects { id: project-id })))
      (match row p
        (begin
(map-set projects { id: project-id }
            { owner: (get owner p),
              name: (get name p),
              created-at: (get created-at p),
              threshold: (get threshold p),
              sum: (get sum p),
              count: (get count p),
              paused: false })
          (ok true))
        ERR-PROJECT-NOT-FOUND))))

(define-public (submit-signal (project-id uint) (score int))
  (begin
    (try! (ensure-active project-id))
    (try! (bounded-score score))
    (let ((seq-row (map-get? project-seq { id: project-id }))
          (proj-row (map-get? projects { id: project-id }))
          (now u0))
      (match seq-row srow
        (match proj-row prow
          (let ((next (+ (get seq srow) u1)))
            ;; store signal
            (map-insert signals { project-id: project-id, seq: next }
              { score: score, at: now })
            ;; update sequence pointer
            (map-set project-seq { id: project-id } { seq: next })
            ;; update cumulative sum and count
            (map-set projects { id: project-id }
              { owner: (get owner prow),
                name: (get name prow),
                created-at: (get created-at prow),
                threshold: (get threshold prow),
                sum: (+ (get sum prow) score),
                count: (+ (get count prow) u1),
                paused: (get paused prow) })
            (ok next))
          ERR-PROJECT-NOT-FOUND)
        ERR-PROJECT-NOT-FOUND))))

;; -----------------------------------------------------------------------------
;; read-only functions
;; -----------------------------------------------------------------------------

(define-read-only (get-project (project-id uint))
  (ok (map-get? projects { id: project-id })))

(define-read-only (get-last-seq (project-id uint))
  (ok (map-get? project-seq { id: project-id })))

(define-read-only (get-signal (project-id uint) (seq uint))
  (ok (map-get? signals { project-id: project-id, seq: seq })))

(define-read-only (get-average (project-id uint))
  (let ((row (map-get? projects { id: project-id })))
    (match row p
      (let ((c (get count p)))
        (if (is-eq c u0)
            (ok 0)
            (ok (/ (get sum p) (to-int c)))))
      ERR-PROJECT-NOT-FOUND)))

(define-read-only (should-pivot (project-id uint))
  (let ((row (map-get? projects { id: project-id })))
    (match row p
      (if (is-eq (get paused p) true)
          (ok false)
          (let ((c (get count p)))
            (if (is-eq c u0)
                (ok false)
                (ok (< (/ (get sum p) (to-int c)) (get threshold p))))))
      ERR-PROJECT-NOT-FOUND)))

(define-read-only (project-owner (project-id uint))
  (let ((row (map-get? projects { id: project-id })))
    (match row p
      (ok (some (get owner p)))
      (ok none))))

