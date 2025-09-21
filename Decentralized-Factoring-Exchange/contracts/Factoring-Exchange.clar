;; Decentralized Factoring Exchange - Marketplace for trading business receivables
;; Version: 1.0.0

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-invalid-status (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-already-exists (err u106))
(define-constant err-expired (err u107))
(define-constant err-invalid-discount (err u108))

;; Data Variables
(define-data-var next-receivable-id uint u1)
(define-data-var platform-fee-rate uint u250) ;; 2.5% (250 basis points)
(define-data-var min-discount-rate uint u100) ;; 1% minimum discount
(define-data-var max-discount-rate uint u3000) ;; 30% maximum discount

;; Status constants
(define-constant status-active u1)
(define-constant status-sold u2)
(define-constant status-paid u3)
(define-constant status-defaulted u4)
(define-constant status-cancelled u5)

;; Data Maps
(define-map receivables
  { receivable-id: uint }
  {
    seller: principal,
    debtor: principal,
    face-value: uint,
    discount-rate: uint, ;; in basis points (100 = 1%)
    discounted-price: uint,
    due-date: uint,
    description: (string-ascii 256),
    status: uint,
    created-at: uint,
    buyer: (optional principal),
    purchased-at: (optional uint)
  }
)

(define-map user-profiles
  { user: principal }
  {
    total-sold: uint,
    total-purchased: uint,
    reputation-score: uint,
    verified: bool
  }
)

(define-map escrow-funds
  { receivable-id: uint }
  {
    amount: uint,
    buyer: principal,
    released: bool
  }
)

;; Read-only functions
(define-read-only (get-receivable (receivable-id uint))
  (map-get? receivables { receivable-id: receivable-id })
)

(define-read-only (get-user-profile (user principal))
  (default-to
    { total-sold: u0, total-purchased: u0, reputation-score: u100, verified: false }
    (map-get? user-profiles { user: user })
  )
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (get-next-receivable-id)
  (var-get next-receivable-id)
)

(define-read-only (calculate-discounted-price (face-value uint) (discount-rate uint))
  (let ((discount-amount (/ (* face-value discount-rate) u10000)))
    (- face-value discount-amount)
  )
)

(define-read-only (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u10000)
)

(define-read-only (is-receivable-expired (receivable-id uint))
  (match (get-receivable receivable-id)
    receivable (> block-height (get due-date receivable))
    false
  )
)

(define-read-only (get-escrow-info (receivable-id uint))
  (map-get? escrow-funds { receivable-id: receivable-id })
)

;; Private functions
(define-private (update-user-stats (user principal) (amount uint) (is-seller bool))
  (let ((current-profile (get-user-profile user)))
    (if is-seller
      (map-set user-profiles
        { user: user }
        (merge current-profile { total-sold: (+ (get total-sold current-profile) amount) })
      )
      (map-set user-profiles
        { user: user }
        (merge current-profile { total-purchased: (+ (get total-purchased current-profile) amount) })
      )
    )
  )
)

;; Public functions

;; Create a new receivable for factoring
(define-public (create-receivable 
  (debtor principal)
  (face-value uint)
  (discount-rate uint)
  (due-date uint)
  (description (string-ascii 256))
)
  (let 
    (
      (receivable-id (var-get next-receivable-id))
      (discounted-price (calculate-discounted-price face-value discount-rate))
    )
    (asserts! (> face-value u0) err-invalid-amount)
    (asserts! (and (>= discount-rate (var-get min-discount-rate)) 
                   (<= discount-rate (var-get max-discount-rate))) err-invalid-discount)
    (asserts! (> due-date block-height) err-expired)
    
    (map-set receivables
      { receivable-id: receivable-id }
      {
        seller: tx-sender,
        debtor: debtor,
        face-value: face-value,
        discount-rate: discount-rate,
        discounted-price: discounted-price,
        due-date: due-date,
        description: description,
        status: status-active,
        created-at: block-height,
        buyer: none,
        purchased-at: none
      }
    )
    
    (var-set next-receivable-id (+ receivable-id u1))
    (ok receivable-id)
  )
)

;; Purchase a receivable
(define-public (purchase-receivable (receivable-id uint))
  (let 
    (
      (receivable (unwrap! (get-receivable receivable-id) err-not-found))
      (purchase-price (get discounted-price receivable))
      (platform-fee (calculate-platform-fee purchase-price))
      (seller-amount (- purchase-price platform-fee))
    )
    (asserts! (is-eq (get status receivable) status-active) err-invalid-status)
    (asserts! (not (is-receivable-expired receivable-id)) err-expired)
    (asserts! (not (is-eq tx-sender (get seller receivable))) err-unauthorized)
    
    ;; Transfer funds to escrow
    (try! (stx-transfer? purchase-price tx-sender (as-contract tx-sender)))
    
    ;; Update receivable status
    (map-set receivables
      { receivable-id: receivable-id }
      (merge receivable { 
        status: status-sold, 
        buyer: (some tx-sender),
        purchased-at: (some block-height)
      })
    )
    
    ;; Set up escrow
    (map-set escrow-funds
      { receivable-id: receivable-id }
      {
        amount: purchase-price,
        buyer: tx-sender,
        released: false
      }
    )
    
    ;; Transfer payment to seller (minus platform fee)
    (try! (as-contract (stx-transfer? seller-amount tx-sender (get seller receivable))))
    
    ;; Update user statistics
    (update-user-stats (get seller receivable) (get face-value receivable) true)
    (update-user-stats tx-sender (get face-value receivable) false)
    
    (ok true)
  )
)

;; Mark receivable as paid by debtor
(define-public (mark-as-paid (receivable-id uint))
  (let 
    (
      (receivable (unwrap! (get-receivable receivable-id) err-not-found))
      (buyer (unwrap! (get buyer receivable) err-not-found))
      (face-value (get face-value receivable))
    )
    (asserts! (is-eq tx-sender (get debtor receivable)) err-unauthorized)
    (asserts! (is-eq (get status receivable) status-sold) err-invalid-status)
    
    ;; Transfer face value from debtor to buyer
    (try! (stx-transfer? face-value tx-sender buyer))
    
    ;; Update receivable status
    (map-set receivables
      { receivable-id: receivable-id }
      (merge receivable { status: status-paid })
    )
    
    ;; Release escrow (if any remaining)
    (match (get-escrow-info receivable-id)
      escrow-info (begin
        (map-set escrow-funds
          { receivable-id: receivable-id }
          (merge escrow-info { released: true })
        )
        (ok true)
      )
      (ok true)
    )
  )
)

;; Cancel receivable (only by seller, only if not sold)
(define-public (cancel-receivable (receivable-id uint))
  (let ((receivable (unwrap! (get-receivable receivable-id) err-not-found)))
    (asserts! (is-eq tx-sender (get seller receivable)) err-unauthorized)
    (asserts! (is-eq (get status receivable) status-active) err-invalid-status)
    
    (map-set receivables
      { receivable-id: receivable-id }
      (merge receivable { status: status-cancelled })
    )
    (ok true)
  )
)

;; Mark receivable as defaulted (can be called by buyer after due date)
(define-public (mark-as-defaulted (receivable-id uint))
  (let ((receivable (unwrap! (get-receivable receivable-id) err-not-found)))
    (asserts! (is-some (get buyer receivable)) err-unauthorized)
    (asserts! (is-eq tx-sender (unwrap-panic (get buyer receivable))) err-unauthorized)
    (asserts! (is-eq (get status receivable) status-sold) err-invalid-status)
    (asserts! (is-receivable-expired receivable-id) err-expired)
    
    (map-set receivables
      { receivable-id: receivable-id }
      (merge receivable { status: status-defaulted })
    )
    (ok true)
  )
)

;; Admin functions

;; Update platform fee rate (only owner)
(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u1000) err-invalid-amount) ;; Max 10%
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)

;; Update discount rate limits (only owner)
(define-public (set-discount-rate-limits (min-rate uint) (max-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (< min-rate max-rate) err-invalid-amount)
    (asserts! (<= max-rate u5000) err-invalid-amount) ;; Max 50%
    (var-set min-discount-rate min-rate)
    (var-set max-discount-rate max-rate)
    (ok true)
  )
)

;; Verify user (only owner)
(define-public (verify-user (user principal))
  (let ((current-profile (get-user-profile user)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set user-profiles
      { user: user }
      (merge current-profile { verified: true })
    )
    (ok true)
  )
)

;; Emergency functions

;; Withdraw platform fees (only owner)
(define-public (withdraw-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
    (ok true)
  )
)