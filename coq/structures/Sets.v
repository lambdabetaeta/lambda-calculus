Require Export Ensembles.
Require Export ssreflect.
Require Export Coq.Classes.RelationClasses.
Require Import Coq.Relations.Relation_Definitions.
Require Export Coq.Program.Equality.  (* for dependent induction *) 
Require Import Coq.Classes.Morphisms.
Require Import Coq.Setoids.Setoid.

(* Representing sets by their characteristic functions. 

   This is a wrapper for `Ensembles` from the Coq standard library.

   It includes notations, Relation classes instances, and a bridge to 
   finite sets represented by lists.

*)

(* Inspired by 
   https://github.com/jsiek/denotational_semantics/agda/SetsAsPredicates.agda *)


Declare Scope set_scope.
Delimit Scope set_scope with Ensemble.
Bind Scope set_scope with Ensemble.

Arguments In {_}.
Arguments Included {_}.
Arguments Union {_}.
Arguments Intersection {_}.
Arguments Same_set {_}.
Arguments Singleton {_}.
Arguments Empty_set {_}.


Module SetNotations. 
  Notation "∅"  := Empty_set : set_scope.
  Notation "x ∈ s"  := (In s x) (at level 90) : set_scope.
  Notation "⌈ x ⌉" := (Singleton x) : set_scope.
  Infix "⊆"  := Included (at level 90) : set_scope.
  Infix "∪"  := Union (at level 90) : set_scope.
  Infix "∩"  := Intersection (at level 90) : set_scope.
  Infix "≃"  := Same_set (at level 90) : set_scope.
End SetNotations. 

Definition P := Ensemble.

Import SetNotations.
Open Scope set_scope.

(* Test cases for notations *)
Check (1 ∈ ⌈ 1 ⌉).
Check (∅ ⊆ ⌈ 1 ⌉).
Check (∅ ∪ ⌈ 1 ⌉).
Check (∅ ∪ ⌈ 1 ⌉ ≃ ∅).


Lemma in_singleton {A:Type} {v : A} : 
  v ∈ ⌈ v ⌉.
Proof. unfold In. econstructor. Qed.

#[export] Hint Resolve in_singleton : core.

(* A proposition that a set is inhabited. Due to the restrictions
   of Coq, the witness cannot be extracted except to produce a 
   proof of a different proposition. *)
Definition nonempty {A} : P A -> Prop := @Inhabited A.

(* This is in Type so that we can extract the witness *)
Definition nonemptyT {A} (s : P A) : Type :=
   {x : A & x ∈ s}.

Arguments nonempty {_}.
Arguments nonemptyT {_}.

Lemma nonemptyT_nonempty {A}{S : P A} : 
  nonemptyT S -> nonempty S.
Proof. intros h. destruct h. econstructor; eauto. Qed.


(* Relation classes *)

#[export] Instance Refl_Incl {A} : Reflexive (@Included A).
intros x. unfold Included. eauto. Qed.

#[export] Instance Trans_Incl {A} : Transitive (@Included A).
intros x y z S1 S2. unfold Included. intro w. eauto. Qed.

#[export] Instance Equivalence_Same_set {A} : Equivalence (@Same_set A) .
constructor.
- unfold Reflexive, Same_set, Included in *. tauto. 
- unfold Symmetric, Same_set, Included in *. tauto.
- unfold Transitive, Same_set, Included in *. intros x y z [h1 h2] [k1 k2]. 
  split; eauto.
Qed.

(* Proper instances: allow rewriting *)

#[export] Instance Union_Included_Proper {A} : Proper (@Included A ==> @Included A ==> @Included A) Union.
Proof. intros a1 a2 Ea b1 b2 Eb.
unfold Included in *. intros x h. inversion h. subst. left. auto. right. auto.
Qed.

#[export] Instance Union_Same_set_Proper {A} : Proper (@Same_set A ==> @Same_set A ==> @Same_set A) Union.
Proof. intros a1 a2 Ea b1 b2 Eb.
unfold Same_set in Ea. unfold Same_set in Eb. move: Ea => [Sa1 Sa2]. move: Eb => [Sb1 Sb2].
split. rewrite -> Sa1. rewrite -> Sb1. reflexivity. rewrite -> Sa2. rewrite -> Sb2. reflexivity. Qed.

#[export] Instance Included_Same_set_Proper {A} : Proper (@Same_set A ==> @Same_set A ==> Logic.iff) Included.
Proof. intros a1 a2 Ea. intros b1 b2 Eb.
       unfold Same_set in Ea. unfold Same_set in Eb. move: Ea => [Sa1 Sa2]. move: Eb => [Sb1 Sb2].
       split. intro h. transitivity a1; auto. transitivity b1; auto. 
       intros h. transitivity a2; auto. transitivity b2; auto. Qed.

#[export] Instance In_Proper {A} : Proper (@Same_set A ==> Logic.eq ==> Logic.iff) (@In A).
Proof. 
  intros a1 a2 [E1 E2]. intros b1 b2 ->.
  split; intro x; eauto.
Qed.


(* Facts about union *)

Lemma sub_union_left {A} (X Y : P A) : X ⊆ (X ∪ Y).
Proof. intros x I.  econstructor; eauto. Qed.

Lemma sub_union_right {A} (X Y : P A) : Y ⊆ (X ∪ Y).
Proof. intros x I. eapply Union_intror; eauto. Qed.

#[export] Hint Resolve sub_union_left sub_union_right : core.

Lemma union_idem {A:Type}{E : P A} : (E ∪ E) ≃ E.
Proof.
  split. intros x h. inversion h; auto.
  intros x h. left. auto.
Qed.

#[export] Hint Resolve union_idem : core.



(* Finite lists `mem` as sets *)

Require Import Coq.Lists.List.

Definition mem {A} : list A -> P A :=
  fun ls x => In x ls.

Lemma mem_one_inv : forall A (h v : A),  
 h ∈ mem (v :: nil) -> h = v.
Proof. 
  intros. cbn in H. destruct H; try done.
Qed. 

(* E≢[]⇒nonempty-mem *)
Lemma nonnil_nonempty_mem : forall{T}{E : list T}, E <> nil -> nonemptyT (mem E).
Proof. intros. destruct E; cbv. done.
       econstructor.
       econstructor. eauto.
Qed.

Lemma mem_head {A} a (V : list A) :
   a ∈ mem (a :: V).
Proof. 
  unfold mem. 
  unfold Ensembles.In.
  econstructor. auto.
Qed.

Lemma mem_cons {A} d a (V : list A) :
    d ∈ mem V ->
    d ∈ mem (a :: V).
Proof. 
  unfold mem. 
  unfold Ensembles.In.
  eapply in_cons.
Qed.

#[export] Hint Resolve mem_head mem_cons mem_one_inv : core.


Lemma union_mem {A:Type}{E1 E2 : list A} : mem (E1 ++ E2) = (mem E1 ∪ mem E2).
Proof. unfold mem. 
       eapply Extensionality_Ensembles.
       split.
       + intros x.
         induction E1. 
         ++ simpl. intro h. right. auto.
         ++ simpl. intro h. inversion h.
            left. unfold In. econstructor; eauto.
            apply IHE1 in H.
            inversion H. subst.
            left. unfold In. eapply in_cons. auto.
            subst. right. auto.
       + intros x.
         induction E1. 
         ++ intro h. inversion h. subst. done. subst. auto.
         ++ simpl. intro h. inversion h; subst.
            destruct H.  left. auto.
            lapply IHE1. intro h2. right. eauto.
            left. eauto. right. apply in_or_app. right. auto.
Qed.

Lemma singleton_mem {A} : forall v : A,  ⌈ v ⌉ ⊆ mem (v :: nil).
Proof. intro v. econstructor. inversion H. done. Qed.

Lemma mem_singleton {A} : forall v : A, mem (v :: nil) ⊆ ⌈ v ⌉.
Proof. intro v. cbv. intros. inversion H. subst. econstructor; eauto. done. Qed.

#[export] Hint Resolve singleton_mem mem_singleton : core. 

(* ----------------------------------------- *)


Definition In : forall {A}, A -> P A -> Prop := 
  fun {A} x p => Ensembles.In p x.

Definition Forall  : forall {A} (Pr : A -> Prop), P A -> Prop := 
  fun {A} Pr p => forall x, In x p -> Pr x.

Definition Exists : forall {A} (Pr : A -> Prop), P A -> Prop :=
  fun {A} Pr p => exists x, In x p /\ Pr x.

Definition  ForallT : forall {A} (Pr : A -> Type), P A -> Type := 
  fun {A} Pr p => forall x, In x p -> Pr x.

Definition ExistsT :  forall {A} (Pr : A -> Type), P A -> Type :=
  fun {A} Pr p => { x & (In x p * Pr x)%type }.

Definition Forall_forall : forall {A} (Pr : A -> Prop) (l : P A), 
      Forall Pr l <-> (forall x, In x l -> Pr x).
Proof. intros. unfold Forall. reflexivity. Qed.

Definition Exists_exists : forall {A} (Pr : A -> Prop) (l : P A), 
      Exists Pr l <-> (exists x, In x l /\ Pr x).
Proof. intros. unfold Exists. reflexivity. Qed.



(* ----------------------------------------- *)

Lemma Forall_mem {A}{V : list A}{Pr} : List.Forall Pr V -> Sets.Forall Pr (mem V).
Proof.
  induction V; intro h; intros y yIn. 
  inversion yIn. 
  inversion h. subst.
  inversion yIn. subst. auto. eapply IHV; eauto.
Qed.

Lemma Forall_sub_mem : forall A (D:list A) X Pr, 
    mem D ⊆ X -> 
    Sets.Forall Pr X ->
    List.Forall Pr D.
Proof.
  intros A D.
  induction D; intros X Pr SUB F.
  eauto.
  econstructor; eauto. eapply F. eapply SUB. eauto.
  eapply IHD with (X:=X); auto. intros x xIn. eapply SUB; eauto.
Qed.

Lemma mem_In : forall A (x:A) l, x ∈ mem l -> List.In x l.
Proof. intros. induction l. cbv in H. done.
       destruct H. subst. econstructor. auto. 
       simpl. right. eauto. Qed.
