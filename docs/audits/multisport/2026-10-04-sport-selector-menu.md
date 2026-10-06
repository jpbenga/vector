# Menu de sélection du sport

Modification locale sur `codex/multisport-hockey`.

Le déclencheur conserve sa place, sa taille et son libellé. Le menu s’ancre sous
le bouton : largeur 236 px, lignes 52 px, hauteur plafonnée à 372 px avec défilement.
Le fond, les textes, la bordure, l’ombre et la coche utilisent les couleurs du thème.
Le sport actif est indiqué par une coche et son icône colorée, sans aplat de sélection.
Les séparateurs sont discrets. Le menu ne contient que des icônes et noms de sports.

Les modules planifiés sont masqués. Football et Hockey sont disponibles ; les
mentions « En préparation » et « À venir » ne sont plus affichées dans le menu.
Le registre de modules continue de fournir les options, sans liste dupliquée dans
l’interface. La sélection du sport actif ferme le menu sans reconstruire sa page.

Vérification : 28 tests ciblés réussis, couvrant la navigation mobile/ordinateur,
l’ancrage sous le bouton, la coche, le masquage des sports planifiés, le défilement
avec dix sports supplémentaires et les règles du design system. Formatage et
git diff --check propres.

Flutter analyze : aucune anomalie. Compilation web réussie en 102,6 secondes.
Vérification visuelle du menu ouvert sur la vraie page hockey : ancrage, deux
options, coche et absence de fond sélectionné confirmés. Capture :
`output/playwright/sport-selector-popover.png`. L’aperçu temporaire a été arrêté.
