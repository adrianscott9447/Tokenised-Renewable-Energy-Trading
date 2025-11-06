(define-data-var owner principal tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_NOT_FOUND (err u301))
(define-constant ERR_INVALID_REASON (err u302))
(define-constant ERR_INVALID_STATUS (err u303))
(define-constant ERR_TRADE_NOT_FOUND (err u304))
(define-constant ERR_NOT_PARTY (err u305))
(define-data-var dispute-nonce uint u0)
(define-data-var total-open uint u0)
(define-data-var total-resolved uint u0)
(define-map disputes uint
  {
    trade-id: uint,
    claimant: principal,
    respondent: principal,
    reason: (string-ascii 128),
    status: (string-ascii 16),
    created-at: uint,
    resolved-at: (optional uint),
    resolution: (optional (string-ascii 128)),
    resolver: (optional principal)
  })
(define-public (create-dispute (verified-trade-id uint) (respondent principal) (reason (string-ascii 128)))
  (let
    (
(trade (unwrap! (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.energy-trading get-trade-history verified-trade-id) ERR_TRADE_NOT_FOUND))
      (buyer (get buyer trade))
      (seller (get seller trade))
      (now block-height)
      (id (+ (var-get dispute-nonce) u1))
    )
    (asserts! (> (len reason) u0) ERR_INVALID_REASON)
    (asserts! (or (is-eq tx-sender buyer) (is-eq tx-sender seller)) ERR_NOT_PARTY)
    (asserts! (or (is-eq respondent buyer) (is-eq respondent seller)) ERR_NOT_PARTY)
    (asserts! (not (is-eq respondent tx-sender)) ERR_NOT_PARTY)
    (map-set disputes id
      {
        trade-id: verified-trade-id,
        claimant: tx-sender,
        respondent: respondent,
        reason: reason,
        status: "open",
        created-at: now,
        resolved-at: none,
        resolution: none,
        resolver: none
      })
    (var-set dispute-nonce id)
    (var-set total-open (+ (var-get total-open) u1))
    (ok id)))
(define-public (resolve-dispute (id uint) (resolution (string-ascii 128)))
  (let
    (
      (d (unwrap! (map-get? disputes id) ERR_NOT_FOUND))
      (now block-height)
    )
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status d) "open") ERR_INVALID_STATUS)
    (asserts! (> (len resolution) u0) ERR_INVALID_REASON)
    (map-set disputes id
      (merge d
        {
          status: "resolved",
          resolved-at: (some now),
          resolution: (some resolution),
          resolver: (some tx-sender)
        }))
    (var-set total-open (- (var-get total-open) u1))
    (var-set total-resolved (+ (var-get total-resolved) u1))
    (ok true)))
(define-read-only (get-dispute (id uint))
  (map-get? disputes id))
(define-read-only (get-dispute-nonce)
  (var-get dispute-nonce))
(define-read-only (get-dispute-stats)
  {open: (var-get total-open), resolved: (var-get total-resolved)})
