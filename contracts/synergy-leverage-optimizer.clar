;; title: synergy-leverage-optimizer
;; version: 1.0.0
;; summary: Register ideas, vote on them, and compute a simple synergy index and leverage ratio.
;; description: Minimal, self-contained contract with no cross-contract calls or trait usage.

;; -----------------------------------------------------------------------------
;; constants and error codes
;; -----------------------------------------------------------------------------

(define-constant ERR-NOT-FOUND (err u100))
(define-constant ERR-NOT-OWNER (err u101))
(define-constant ERR-EMPTY-TITLE (err u102))
(define-constant ERR-EMPTY-DESC (err u103))
(define-constant ERR-RANGE (err u104))

(define-constant MAX-TITLE-LEN u128)
(define-constant MAX-DESC-LEN u256)
(define-constant MAX-SCORE u100)

;; -----------------------------------------------------------------------------
;; data vars
;; -----------------------------------------------------------------------------

(define-data-var next-id uint u1)

;; -----------------------------------------------------------------------------
;; data maps
;; -----------------------------------------------------------------------------

(define-map ideas
  { id: uint }
  { owner: principal,
    title: (string-ascii 128),
    description: (string-ascii 256),
    created-at: uint })

(define-map idea-scores
  { id: uint }
  { synergy: uint,
    leverage: uint,
    upvotes: uint,
    downvotes: uint })

(define-map user-stats
  { user: principal }
  { submitted: uint,
    upvotes: uint,
    downvotes: uint })

;; -----------------------------------------------------------------------------
;; private helpers
;; -----------------------------------------------------------------------------

(define-private (idea-exists (id uint))
  (is-some (map-get? ideas { id: id })))

(define-private (only-owner (id uint))
  (let ((found (map-get? ideas { id: id })))
    (match found idea
      (begin
        (if (is-eq (get owner idea) tx-sender)
            (ok true)
            ERR-NOT-OWNER))
      ERR-NOT-FOUND)))

(define-private (bounded (x uint))
  (if (<= x MAX-SCORE) (ok x) ERR-RANGE))

(define-private (update-user-upvote (user principal))
  (let ((row (map-get? user-stats { user: user })))
    (match row val
      (begin
        (map-set user-stats { user: user }
          { submitted: (get submitted val),
            upvotes: (+ u1 (get upvotes val)),
            downvotes: (get downvotes val) })
        true)
      (begin
        (map-insert user-stats { user: user }
          { submitted: u0, upvotes: u1, downvotes: u0 })
        true))))

(define-private (update-user-downvote (user principal))
  (let ((row (map-get? user-stats { user: user })))
    (match row val
      (begin
        (map-set user-stats { user: user }
          { submitted: (get submitted val),
            upvotes: (get upvotes val),
            downvotes: (+ u1 (get downvotes val)) })
        true)
      (begin
        (map-insert user-stats { user: user }
          { submitted: u0, upvotes: u0, downvotes: u1 })
        true))))

(define-private (inc-submitted (user principal))
  (let ((row (map-get? user-stats { user: user })))
    (match row val
      (begin
        (map-set user-stats { user: user }
          { submitted: (+ u1 (get submitted val)),
            upvotes: (get upvotes val),
            downvotes: (get downvotes val) })
        true)
      (begin
        (map-insert user-stats { user: user }
          { submitted: u1, upvotes: u0, downvotes: u0 })
        true))))

;; -----------------------------------------------------------------------------
;; public functions
;; -----------------------------------------------------------------------------

(define-public (create-idea (title (string-ascii 128)) (description (string-ascii 256)))
  (if (is-eq title "")
      ERR-EMPTY-TITLE
      (if (is-eq description "")
          ERR-EMPTY-DESC
          (let ((id (var-get next-id))
                (now u0))
            (inc-submitted tx-sender)
            (map-insert ideas { id: id }
              { owner: tx-sender, title: title, description: description, created-at: now })
            (map-insert idea-scores { id: id }
              { synergy: u0, leverage: u0, upvotes: u0, downvotes: u0 })
            (var-set next-id (+ id u1))
            (ok id)))))

(define-public (set-synergy (id uint) (value uint))
  (begin
    (try! (only-owner id))
    (try! (bounded value))
    (let ((row (map-get? idea-scores { id: id })))
      (match row r
        (begin
(map-set idea-scores { id: id }
            { synergy: value,
              leverage: (get leverage r),
              upvotes: (get upvotes r),
              downvotes: (get downvotes r) })
          (ok true))
        ERR-NOT-FOUND))))

(define-public (set-leverage (id uint) (value uint))
  (begin
    (try! (only-owner id))
    (try! (bounded value))
    (let ((row (map-get? idea-scores { id: id })))
      (match row r
        (begin
(map-set idea-scores { id: id }
            { synergy: (get synergy r),
              leverage: value,
              upvotes: (get upvotes r),
              downvotes: (get downvotes r) })
          (ok true))
        ERR-NOT-FOUND))))

(define-public (upvote (id uint))
  (let ((row (map-get? idea-scores { id: id })))
    (match row r
      (begin
        (map-set idea-scores { id: id }
          { synergy: (get synergy r),
            leverage: (get leverage r),
            upvotes: (+ u1 (get upvotes r)),
            downvotes: (get downvotes r) })
        (update-user-upvote tx-sender)
        (ok true))
      ERR-NOT-FOUND)))

(define-public (downvote (id uint))
  (let ((row (map-get? idea-scores { id: id })))
    (match row r
      (begin
        (map-set idea-scores { id: id }
          { synergy: (get synergy r),
            leverage: (get leverage r),
            upvotes: (get upvotes r),
            downvotes: (+ u1 (get downvotes r)) })
        (update-user-downvote tx-sender)
        (ok true))
      ERR-NOT-FOUND)))

(define-public (transfer-ownership (id uint) (new-owner principal))
  (begin
    (try! (only-owner id))
    (let ((found (map-get? ideas { id: id })))
      (match found idea
        (begin
(map-set ideas { id: id }
            { owner: new-owner,
              title: (get title idea),
              description: (get description idea),
              created-at: (get created-at idea) })
          (ok true))
        ERR-NOT-FOUND))))

;; -----------------------------------------------------------------------------
;; read-only functions
;; -----------------------------------------------------------------------------

(define-read-only (get-idea (id uint))
  (ok (map-get? ideas { id: id })))

(define-read-only (get-score (id uint))
  (ok (map-get? idea-scores { id: id })))

(define-read-only (get-user-stats (user principal))
  (ok (map-get? user-stats { user: user })))

(define-read-only (get-index (id uint))
  (let ((score (map-get? idea-scores { id: id })))
    (match score s
      (let (
            (base (+ (* (get synergy s) u2)
                     (* (get leverage s) u3)))
            (up (get upvotes s))
            (down (get downvotes s))
           )
        (let ((net (if (>= up down) (- up down) u0)))
          (ok (+ base net))))
      ERR-NOT-FOUND)))

(define-read-only (owner-of (id uint))
  (let ((found (map-get? ideas { id: id })))
    (match found idea
      (ok (some (get owner idea)))
      (ok none))))

