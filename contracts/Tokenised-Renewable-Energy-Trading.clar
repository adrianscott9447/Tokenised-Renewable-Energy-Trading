(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-producer-not-found (err u104))
(define-constant err-invalid-price (err u105))
(define-constant err-order-not-found (err u106))
(define-constant err-cannot-buy-own-tokens (err u107))
(define-constant err-producer-not-verified (err u108))

(define-fungible-token green-energy-token)

(define-map energy-producers
    principal
    {
        verified: bool,
        energy-produced: uint,
        tokens-minted: uint,
        price-per-token: uint,
        reputation-score: uint,
    }
)

(define-map energy-consumers
    principal
    {
        energy-consumed: uint,
        tokens-purchased: uint,
        total-spent: uint,
    }
)

(define-map sell-orders
    uint
    {
        seller: principal,
        amount: uint,
        price-per-token: uint,
        active: bool,
        created-at: uint,
    }
)

(define-map buy-orders
    uint
    {
        buyer: principal,
        amount: uint,
        max-price: uint,
        active: bool,
        created-at: uint,
    }
)

(define-data-var next-sell-order-id uint u1)
(define-data-var next-buy-order-id uint u1)
(define-data-var total-energy-produced uint u0)
(define-data-var total-energy-consumed uint u0)
(define-data-var platform-fee-rate uint u25)

(define-read-only (get-energy-producer (producer principal))
    (map-get? energy-producers producer)
)

(define-read-only (get-energy-consumer (consumer principal))
    (map-get? energy-consumers consumer)
)

(define-read-only (get-sell-order (order-id uint))
    (map-get? sell-orders order-id)
)

(define-read-only (get-buy-order (order-id uint))
    (map-get? buy-orders order-id)
)

(define-read-only (get-token-balance (account principal))
    (ft-get-balance green-energy-token account)
)

(define-read-only (get-total-supply)
    (ft-get-supply green-energy-token)
)

(define-read-only (get-platform-stats)
    {
        total-energy-produced: (var-get total-energy-produced),
        total-energy-consumed: (var-get total-energy-consumed),
        total-supply: (ft-get-supply green-energy-token),
        platform-fee-rate: (var-get platform-fee-rate),
    }
)

(define-public (register-producer (price-per-token uint))
    (begin
        (asserts! (> price-per-token u0) err-invalid-price)
        (map-set energy-producers tx-sender {
            verified: false,
            energy-produced: u0,
            tokens-minted: u0,
            price-per-token: price-per-token,
            reputation-score: u0,
        })
        (ok true)
    )
)

(define-public (verify-producer (producer principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (let ((producer-data (unwrap! (map-get? energy-producers producer) err-producer-not-found)))
            (map-set energy-producers producer
                (merge producer-data { verified: true })
            )
            (ok true)
        )
    )
)

(define-public (mint-energy-tokens (amount uint))
    (let ((producer-data (unwrap! (map-get? energy-producers tx-sender) err-producer-not-found)))
        (asserts! (get verified producer-data) err-producer-not-verified)
        (asserts! (> amount u0) err-invalid-amount)
        (try! (ft-mint? green-energy-token amount tx-sender))
        (map-set energy-producers tx-sender
            (merge producer-data {
                energy-produced: (+ (get energy-produced producer-data) amount),
                tokens-minted: (+ (get tokens-minted producer-data) amount),
            })
        )
        (var-set total-energy-produced (+ (var-get total-energy-produced) amount))
        (ok amount)
    )
)

(define-public (create-sell-order
        (amount uint)
        (price-per-token uint)
    )
    (let ((order-id (var-get next-sell-order-id)))
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (> price-per-token u0) err-invalid-price)
        (asserts! (>= (ft-get-balance green-energy-token tx-sender) amount)
            err-insufficient-balance
        )
        (map-set sell-orders order-id {
            seller: tx-sender,
            amount: amount,
            price-per-token: price-per-token,
            active: true,
            created-at: stacks-block-height,
        })
        (var-set next-sell-order-id (+ order-id u1))
        (ok order-id)
    )
)

(define-public (create-buy-order
        (amount uint)
        (max-price uint)
    )
    (let (
            (order-id (var-get next-buy-order-id))
            (total-cost (* amount max-price))
        )
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (> max-price u0) err-invalid-price)
        (asserts! (>= (stx-get-balance tx-sender) total-cost)
            err-insufficient-balance
        )
        (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
        (map-set buy-orders order-id {
            buyer: tx-sender,
            amount: amount,
            max-price: max-price,
            active: true,
            created-at: stacks-block-height,
        })
        (var-set next-buy-order-id (+ order-id u1))
        (ok order-id)
    )
)

(define-public (execute-sell-order (order-id uint))
    (let ((order (unwrap! (map-get? sell-orders order-id) err-order-not-found)))
        (asserts! (get active order) err-order-not-found)
        (asserts! (not (is-eq tx-sender (get seller order)))
            err-cannot-buy-own-tokens
        )
        (let (
                (amount (get amount order))
                (price-per-token (get price-per-token order))
                (total-cost (* amount price-per-token))
                (platform-fee (/ (* total-cost (var-get platform-fee-rate)) u10000))
                (seller-amount (- total-cost platform-fee))
            )
            (try! (stx-transfer? total-cost tx-sender (get seller order)))
            (try! (ft-transfer? green-energy-token amount (get seller order) tx-sender))
            (if (> platform-fee u0)
                (try! (stx-transfer? platform-fee (get seller order) contract-owner))
                true
            )
            (map-set sell-orders order-id (merge order { active: false }))
            (update-consumer-stats tx-sender amount total-cost)
            (update-producer-reputation (get seller order) amount)
            (ok true)
        )
    )
)

(define-public (execute-buy-order (order-id uint))
    (let ((order (unwrap! (map-get? buy-orders order-id) err-order-not-found)))
        (asserts! (get active order) err-order-not-found)
        (asserts! (not (is-eq tx-sender (get buyer order)))
            err-cannot-buy-own-tokens
        )
        (let (
                (amount (get amount order))
                (max-price (get max-price order))
                (total-cost (* amount max-price))
                (platform-fee (/ (* total-cost (var-get platform-fee-rate)) u10000))
                (buyer-payment (- total-cost platform-fee))
            )
            (asserts! (>= (ft-get-balance green-energy-token tx-sender) amount)
                err-insufficient-balance
            )
            (try! (ft-transfer? green-energy-token amount tx-sender (get buyer order)))
            (try! (as-contract (stx-transfer? buyer-payment tx-sender (get buyer order))))
            (if (> platform-fee u0)
                (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))
                true
            )
            (map-set buy-orders order-id (merge order { active: false }))
            (update-consumer-stats (get buyer order) amount total-cost)
            (update-producer-reputation tx-sender amount)
            (ok true)
        )
    )
)

(define-public (cancel-sell-order (order-id uint))
    (let ((order (unwrap! (map-get? sell-orders order-id) err-order-not-found)))
        (asserts! (is-eq tx-sender (get seller order)) err-not-authorized)
        (asserts! (get active order) err-order-not-found)
        (map-set sell-orders order-id (merge order { active: false }))
        (ok true)
    )
)

(define-public (cancel-buy-order (order-id uint))
    (let ((order (unwrap! (map-get? buy-orders order-id) err-order-not-found)))
        (asserts! (is-eq tx-sender (get buyer order)) err-not-authorized)
        (asserts! (get active order) err-order-not-found)
        (let ((refund-amount (* (get amount order) (get max-price order))))
            (try! (as-contract (stx-transfer? refund-amount tx-sender (get buyer order))))
            (map-set buy-orders order-id (merge order { active: false }))
            (ok true)
        )
    )
)

(define-public (transfer-tokens
        (amount uint)
        (recipient principal)
    )
    (begin
        (asserts! (> amount u0) err-invalid-amount)
        (ft-transfer? green-energy-token amount tx-sender recipient)
    )
)

(define-public (update-producer-price (new-price uint))
    (let ((producer-data (unwrap! (map-get? energy-producers tx-sender) err-producer-not-found)))
        (asserts! (> new-price u0) err-invalid-price)
        (map-set energy-producers tx-sender
            (merge producer-data { price-per-token: new-price })
        )
        (ok true)
    )
)

(define-public (set-platform-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-rate u1000) err-invalid-amount)
        (var-set platform-fee-rate new-rate)
        (ok true)
    )
)

(define-private (update-consumer-stats
        (consumer principal)
        (amount uint)
        (cost uint)
    )
    (let ((consumer-data (default-to {
            energy-consumed: u0,
            tokens-purchased: u0,
            total-spent: u0,
        }
            (map-get? energy-consumers consumer)
        )))
        (map-set energy-consumers consumer {
            energy-consumed: (+ (get energy-consumed consumer-data) amount),
            tokens-purchased: (+ (get tokens-purchased consumer-data) amount),
            total-spent: (+ (get total-spent consumer-data) cost),
        })
        (var-set total-energy-consumed (+ (var-get total-energy-consumed) amount))
    )
)

(define-private (update-producer-reputation
        (producer principal)
        (amount uint)
    )
    (let ((producer-data (unwrap-panic (map-get? energy-producers producer))))
        (map-set energy-producers producer
            (merge producer-data { reputation-score: (+ (get reputation-score producer-data) (/ amount u10)) })
        )
    )
)
