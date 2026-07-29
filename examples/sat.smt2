; Satisfiable query — the obligation does NOT hold (x = #x29 is a model).
; Used as the negative fixture: ordeal_check on this file must FAIL.
(set-logic QF_BV)
(declare-const x (_ BitVec 8))
(assert (= (bvadd x #x01) #x2a))
(check-sat)
