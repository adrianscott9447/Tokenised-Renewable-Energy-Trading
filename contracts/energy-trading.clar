;; Energy Trading Platform Smart Contract
;; Tokenised renewable energy trading on Stacks blockchain

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_LISTING_NOT_FOUND (err u103))
(define-constant ERR_INVALID_PRICE (err u104))
(define-constant ERR_SELF_PURCHASE (err u105))
(define-constant ERR_LISTING_EXPIRED (err u106))
(define-constant ERR_ALREADY_CLAIMED (err u107))

;; Token definition
(define-fungible-token green-energy-token)

;; Data variables
(define-data-var token-name (string-ascii 32) "Green Energy Token")
(define-data-var token-symbol (string-ascii 10) "GET")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var token-decimals uint u6)
(define-data-var total-supply uint u0)
(define-data-var listing-nonce uint u0)

;; Energy producer registry
(define-map energy-producers principal 
  {
    name: (string-ascii 64),
    energy-source: (string-ascii 32),
    verified: bool,
    total-produced: uint,
    reputation-score: uint
  })

;; Energy listings for trading
(define-map energy-listings uint
  {
    producer: principal,
    amount: uint,
    price-per-kwh: uint,
    expiry-block: uint,
    active: bool,
    buyer: (optional principal)
  })

;; Energy production records
(define-map production-records {producer: principal, timestamp: uint}
  {
    amount: uint,
    source-type: (string-ascii 32),
    verified: bool,
    certificate-hash: (string-ascii 64)
  })

;; Trading history
(define-map trading-history uint
  {
    buyer: principal,
    seller: principal,
    amount: uint,
    price: uint,
    timestamp: uint
  })

;; SIP-010 Standard Functions

(define-read-only (get-name)
  (ok (var-get token-name)))

(define-read-only (get-symbol)
  (ok (var-get token-symbol)))

(define-read-only (get-decimals)
  (ok (var-get token-decimals)))

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance green-energy-token who)))

(define-read-only (get-total-supply)
  (ok (ft-get-supply green-energy-token)))

(define-read-only (get-token-uri)
  (ok (var-get token-uri)))

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq tx-sender from) (is-eq contract-caller from)) ERR_UNAUTHORIZED)
    (ft-transfer? green-energy-token amount from to)))

;; Producer registration
(define-public (register-producer (name (string-ascii 64)) (energy-source (string-ascii 32)))
  (begin
    (asserts! (> (len name) u0) (err u108))
    (asserts! (> (len energy-source) u0) (err u109))
    (map-set energy-producers tx-sender
      {
        name: name,
        energy-source: energy-source,
        verified: false,
        total-produced: u0,
        reputation-score: u100
      })
    (ok true)))

;; Verify producer (admin only)
(define-public (verify-producer (producer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? energy-producers producer)
      producer-data 
        (begin
          (map-set energy-producers producer
            (merge producer-data {verified: true}))
          (ok true))
      ERR_UNAUTHORIZED)))

;; Record energy production
(define-public (record-production (amount uint) (source-type (string-ascii 32)) (certificate-hash (string-ascii 64)))
  (let
    (
      (producer-data (unwrap! (map-get? energy-producers tx-sender) ERR_UNAUTHORIZED))
      (timestamp (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (get verified producer-data) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Record production
    (map-set production-records {producer: tx-sender, timestamp: timestamp}
      {
        amount: amount,
        source-type: source-type,
        verified: true,
        certificate-hash: certificate-hash
      })
    
    ;; Update producer stats
    (map-set energy-producers tx-sender
      (merge producer-data 
        {
          total-produced: (+ (get total-produced producer-data) amount),
          reputation-score: (+ (get reputation-score producer-data) u5)
        }))
    
    ;; Mint tokens for production
    (try! (ft-mint? green-energy-token amount tx-sender))
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok amount)))

;; Create energy listing
(define-public (create-listing (amount uint) (price-per-kwh uint) (duration-blocks uint))
  (let
    (
      (listing-id (+ (var-get listing-nonce) u1))
      (expiry-block (+ block-height duration-blocks))
      (balance (ft-get-balance green-energy-token tx-sender))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> price-per-kwh u0) ERR_INVALID_PRICE)
    (asserts! (>= balance amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (> duration-blocks u0) (err u110))
    
    ;; Lock tokens in escrow
    (try! (ft-transfer? green-energy-token amount tx-sender (as-contract tx-sender)))
    
    ;; Create listing
    (map-set energy-listings listing-id
      {
        producer: tx-sender,
        amount: amount,
        price-per-kwh: price-per-kwh,
        expiry-block: expiry-block,
        active: true,
        buyer: none
      })
    
    (var-set listing-nonce listing-id)
    (ok listing-id)))

;; Purchase energy from listing
(define-public (purchase-energy (listing-id uint))
  (let
    (
      (listing (unwrap! (map-get? energy-listings listing-id) ERR_LISTING_NOT_FOUND))
      (total-price (* (get amount listing) (get price-per-kwh listing)))
    )
    (asserts! (get active listing) ERR_LISTING_NOT_FOUND)
    (asserts! (< block-height (get expiry-block listing)) ERR_LISTING_EXPIRED)
    (asserts! (not (is-eq tx-sender (get producer listing))) ERR_SELF_PURCHASE)
    (asserts! (>= (stx-get-balance tx-sender) total-price) ERR_INSUFFICIENT_BALANCE)
    
    ;; Transfer payment to producer
    (try! (stx-transfer? total-price tx-sender (get producer listing)))
    
    ;; Transfer tokens from escrow to buyer
    (try! (as-contract (ft-transfer? green-energy-token (get amount listing) tx-sender (get producer listing))))
    (try! (ft-transfer? green-energy-token (get amount listing) (get producer listing) tx-sender))
    
    ;; Update listing
    (map-set energy-listings listing-id
      (merge listing {active: false, buyer: (some tx-sender)}))
    
    ;; Record trade
    (map-set trading-history listing-id
      {
        buyer: tx-sender,
        seller: (get producer listing),
        amount: (get amount listing),
        price: total-price,
        timestamp: (unwrap-panic (get-block-info? time (- block-height u1)))
      })
    
    (ok true)))

;; Cancel listing (producer only)
(define-public (cancel-listing (listing-id uint))
  (let
    (
      (listing (unwrap! (map-get? energy-listings listing-id) ERR_LISTING_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get producer listing)) ERR_UNAUTHORIZED)
    (asserts! (get active listing) ERR_LISTING_NOT_FOUND)
    
    ;; Return tokens from escrow
    (try! (as-contract (ft-transfer? green-energy-token (get amount listing) tx-sender (get producer listing))))
    
    ;; Deactivate listing
    (map-set energy-listings listing-id
      (merge listing {active: false}))
    
    (ok true)))

;; Read-only functions

(define-read-only (get-producer-info (producer principal))
  (map-get? energy-producers producer))

(define-read-only (get-listing (listing-id uint))
  (map-get? energy-listings listing-id))

(define-read-only (get-production-record (producer principal) (timestamp uint))
  (map-get? production-records {producer: producer, timestamp: timestamp}))

(define-read-only (get-trade-history (trade-id uint))
  (map-get? trading-history trade-id))

(define-read-only (get-listing-nonce)
  (var-get listing-nonce))

;; Emergency functions (admin only)
(define-public (emergency-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    ;; Emergency pause logic would go here
    (ok true)))

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set token-uri new-uri)
    (ok true)))