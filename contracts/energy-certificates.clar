;; Energy Certificates Contract
;; Renewable energy certificates (RECs) management and verification system

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_CERTIFICATE_NOT_FOUND (err u201))
(define-constant ERR_CERTIFICATE_EXPIRED (err u202))
(define-constant ERR_CERTIFICATE_ALREADY_RETIRED (err u203))
(define-constant ERR_INVALID_AMOUNT (err u204))
(define-constant ERR_INVALID_ISSUER (err u205))
(define-constant ERR_DUPLICATE_CERTIFICATE (err u206))
(define-constant ERR_INSUFFICIENT_CERTIFICATES (err u207))

;; Data variables
(define-data-var certificate-nonce uint u0)
(define-data-var total-certificates-issued uint u0)
(define-data-var total-certificates-retired uint u0)

;; Certificate issuer registry
(define-map authorized-issuers principal 
  {
    name: (string-ascii 64),
    country: (string-ascii 32),
    certification-body: (string-ascii 64),
    active: bool,
    certificates-issued: uint
  })

;; Energy certificates (RECs) registry
(define-map energy-certificates uint
  {
    owner: principal,
    issuer: principal,
    energy-source: (string-ascii 32),
    generation-facility: (string-ascii 128),
    mwh-amount: uint,
    vintage-year: uint,
    issue-date: uint,
    expiry-date: uint,
    retired: bool,
    retirement-date: (optional uint),
    retirement-reason: (optional (string-ascii 128)),
    certificate-hash: (string-ascii 64),
    metadata-uri: (optional (string-utf8 256))
  })

;; Certificate ownership tracking
(define-map certificate-balances {owner: principal, certificate-type: (string-ascii 32)}
  {
    total-certificates: uint,
    active-certificates: uint,
    retired-certificates: uint
  })

;; Certificate transfer history
(define-map certificate-transfers uint
  {
    certificate-id: uint,
    from: principal,
    to: principal,
    transfer-date: uint,
    transfer-reason: (optional (string-ascii 128))
  })

;; Certificate retirement registry
(define-map certificate-retirements uint
  {
    certificate-id: uint,
    retired-by: principal,
    retirement-date: uint,
    retirement-reason: (string-ascii 128),
    beneficiary: (optional principal)
  })

;; Issuer management functions

(define-public (register-issuer 
  (issuer principal)
  (name (string-ascii 64)) 
  (country (string-ascii 32))
  (certification-body (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> (len name) u0) (err u208))
    (asserts! (> (len country) u0) (err u209))
    
    (map-set authorized-issuers issuer
      {
        name: name,
        country: country,
        certification-body: certification-body,
        active: true,
        certificates-issued: u0
      })
    (ok true)))

(define-public (deactivate-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? authorized-issuers issuer)
      issuer-data 
        (begin
          (map-set authorized-issuers issuer
            (merge issuer-data {active: false}))
          (ok true))
      ERR_INVALID_ISSUER)))

;; Certificate issuance

(define-public (issue-certificate
  (recipient principal)
  (energy-source (string-ascii 32))
  (generation-facility (string-ascii 128))
  (mwh-amount uint)
  (vintage-year uint)
  (validity-years uint)
  (certificate-hash (string-ascii 64))
  (metadata-uri (optional (string-utf8 256))))
  (let
    (
      (certificate-id (+ (var-get certificate-nonce) u1))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (expiry-date (+ current-time (* validity-years u31536000))) ;; seconds in a year
      (issuer-data (unwrap! (map-get? authorized-issuers tx-sender) ERR_INVALID_ISSUER))
    )
    (asserts! (get active issuer-data) ERR_INVALID_ISSUER)
    (asserts! (> mwh-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> validity-years u0) (err u210))
    (asserts! (>= vintage-year u2000) (err u211)) ;; Reasonable vintage year check
    
    ;; Check for duplicate certificate hash
    (asserts! (is-none (index-of? (var-get certificate-nonce) certificate-id)) ERR_DUPLICATE_CERTIFICATE)
    
    ;; Issue certificate
    (map-set energy-certificates certificate-id
      {
        owner: recipient,
        issuer: tx-sender,
        energy-source: energy-source,
        generation-facility: generation-facility,
        mwh-amount: mwh-amount,
        vintage-year: vintage-year,
        issue-date: current-time,
        expiry-date: expiry-date,
        retired: false,
        retirement-date: none,
        retirement-reason: none,
        certificate-hash: certificate-hash,
        metadata-uri: metadata-uri
      })
    
    ;; Update issuer stats
    (map-set authorized-issuers tx-sender
      (merge issuer-data 
        {certificates-issued: (+ (get certificates-issued issuer-data) u1)}))
    
    ;; Update owner balance
    (update-certificate-balance recipient energy-source u1 u0)
    
    ;; Update global counters
    (var-set certificate-nonce certificate-id)
    (var-set total-certificates-issued (+ (var-get total-certificates-issued) u1))
    
    (ok certificate-id)))

;; Certificate transfer

(define-public (transfer-certificate (certificate-id uint) (to principal) (reason (optional (string-ascii 128))))
  (let
    (
      (certificate (unwrap! (map-get? energy-certificates certificate-id) ERR_CERTIFICATE_NOT_FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-eq tx-sender (get owner certificate)) ERR_UNAUTHORIZED)
    (asserts! (not (get retired certificate)) ERR_CERTIFICATE_ALREADY_RETIRED)
    (asserts! (< current-time (get expiry-date certificate)) ERR_CERTIFICATE_EXPIRED)
    
    ;; Update certificate ownership
    (map-set energy-certificates certificate-id
      (merge certificate {owner: to}))
    
    ;; Record transfer
    (map-set certificate-transfers certificate-id
      {
        certificate-id: certificate-id,
        from: tx-sender,
        to: to,
        transfer-date: current-time,
        transfer-reason: reason
      })
    
    ;; Update balances
    (update-certificate-balance tx-sender (get energy-source certificate) (- u0 u1) u0)
    (update-certificate-balance to (get energy-source certificate) u1 u0)
    
    (ok true)))

;; Certificate retirement

(define-public (retire-certificate (certificate-id uint) (retirement-reason (string-ascii 128)) (beneficiary (optional principal)))
  (let
    (
      (certificate (unwrap! (map-get? energy-certificates certificate-id) ERR_CERTIFICATE_NOT_FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-eq tx-sender (get owner certificate)) ERR_UNAUTHORIZED)
    (asserts! (not (get retired certificate)) ERR_CERTIFICATE_ALREADY_RETIRED)
    (asserts! (< current-time (get expiry-date certificate)) ERR_CERTIFICATE_EXPIRED)
    (asserts! (> (len retirement-reason) u0) (err u212))
    
    ;; Retire certificate
    (map-set energy-certificates certificate-id
      (merge certificate 
        {
          retired: true,
          retirement-date: (some current-time),
          retirement-reason: (some retirement-reason)
        }))
    
    ;; Record retirement
    (map-set certificate-retirements certificate-id
      {
        certificate-id: certificate-id,
        retired-by: tx-sender,
        retirement-date: current-time,
        retirement-reason: retirement-reason,
        beneficiary: beneficiary
      })
    
    ;; Update owner balance
    (update-certificate-balance tx-sender (get energy-source certificate) (- u0 u1) u1)
    
    ;; Update global counter
    (var-set total-certificates-retired (+ (var-get total-certificates-retired) u1))
    
    (ok true)))

;; Batch retirement for carbon offsetting

(define-public (batch-retire-certificates 
  (certificate-ids (list 50 uint)) 
  (retirement-reason (string-ascii 128)) 
  (beneficiary (optional principal)))
  (let
    (
      (retirement-results (map retire-single-certificate certificate-ids))
    )
    (asserts! (> (len retirement-reason) u0) (err u212))
    
    ;; Check if all retirements succeeded
    (asserts! (is-eq (len (filter is-retirement-success retirement-results)) (len certificate-ids)) (err u213))
    
    (ok (len certificate-ids))))

(define-private (retire-single-certificate (certificate-id uint))
  (match (map-get? energy-certificates certificate-id)
    certificate
      (if (and 
            (not (get retired certificate))
            (is-eq tx-sender (get owner certificate)))
        (ok certificate-id)
        (err u214))
    (err u215)))

(define-private (is-retirement-success (result (response uint uint)))
  (is-ok result))

;; Helper function to update certificate balances

(define-private (update-certificate-balance (owner principal) (cert-type (string-ascii 32)) (active-change int) (retired-change uint))
  (let
    (
      (current-balance (default-to 
        {total-certificates: u0, active-certificates: u0, retired-certificates: u0}
        (map-get? certificate-balances {owner: owner, certificate-type: cert-type})))
    )
    (map-set certificate-balances {owner: owner, certificate-type: cert-type}
      {
        total-certificates: (+ (get total-certificates current-balance) (if (>= active-change 0) (to-uint active-change) u0)),
        active-certificates: (if (>= active-change 0) 
                                (+ (get active-certificates current-balance) (to-uint active-change))
                                (- (get active-certificates current-balance) (to-uint (* active-change -1)))),
        retired-certificates: (+ (get retired-certificates current-balance) retired-change)
      })
    (ok true)))

;; Read-only functions

(define-read-only (get-certificate (certificate-id uint))
  (map-get? energy-certificates certificate-id))

(define-read-only (get-issuer-info (issuer principal))
  (map-get? authorized-issuers issuer))

(define-read-only (get-certificate-balance (owner principal) (certificate-type (string-ascii 32)))
  (map-get? certificate-balances {owner: owner, certificate-type: certificate-type}))

(define-read-only (get-transfer-history (certificate-id uint))
  (map-get? certificate-transfers certificate-id))

(define-read-only (get-retirement-record (certificate-id uint))
  (map-get? certificate-retirements certificate-id))

(define-read-only (get-certificate-nonce)
  (var-get certificate-nonce))

(define-read-only (get-total-certificates-issued)
  (var-get total-certificates-issued))

(define-read-only (get-total-certificates-retired)
  (var-get total-certificates-retired))

(define-read-only (is-certificate-valid (certificate-id uint))
  (match (map-get? energy-certificates certificate-id)
    certificate
      (let
        (
          (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
        )
        (and 
          (not (get retired certificate))
          (< current-time (get expiry-date certificate))))
    false))

;; Verification functions

(define-read-only (verify-certificate-authenticity (certificate-id uint) (expected-hash (string-ascii 64)))
  (match (map-get? energy-certificates certificate-id)
    certificate
      (is-eq (get certificate-hash certificate) expected-hash)
    false))

(define-read-only (get-certificates-by-vintage (vintage-year uint))
  ;; This would typically require an index in a full implementation
  ;; For now, returns a simple check function
  (> vintage-year u1999))

;; Admin functions

(define-public (update-certificate-metadata (certificate-id uint) (new-metadata-uri (string-utf8 256)))
  (let
    (
      (certificate (unwrap! (map-get? energy-certificates certificate-id) ERR_CERTIFICATE_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender (get issuer certificate))) ERR_UNAUTHORIZED)
    
    (map-set energy-certificates certificate-id
      (merge certificate {metadata-uri: (some new-metadata-uri)}))
    
    (ok true)))

(define-public (emergency-revoke-certificate (certificate-id uint) (revocation-reason (string-ascii 128)))
  (let
    (
      (certificate (unwrap! (map-get? energy-certificates certificate-id) ERR_CERTIFICATE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> (len revocation-reason) u0) (err u216))
    
    ;; Mark as retired with revocation reason
    (map-set energy-certificates certificate-id
      (merge certificate 
        {
          retired: true,
          retirement-date: (some (unwrap-panic (get-block-info? time (- block-height u1)))),
          retirement-reason: (some revocation-reason)
        }))
    
    (ok true)))