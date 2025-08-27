Avec cette partie, nous commençons jlox, le premier de nos deux interpréteurs. Les
langages de programmation sont un sujet énorme avec des tas de concepts et de
terminologie à fourrer dans votre cerveau d'un coup. La théorie des langages de
programmation nécessite un niveau de rigueur mentale que vous n'avez probablement
pas eu à invoquer depuis votre dernier examen de calcul différentiel. (Heureusement
il n'y a pas trop de théorie dans ce livre.)

Implémenter un interpréteur utilise quelques astuces architecturales et modèles
de conception peu communs dans d'autres types d'applications, donc nous nous
habituerons aussi au côté ingénierie des choses. Étant donné tout cela, nous
garderons le code que nous devons écrire aussi simple et clair que possible.

En moins de deux mille lignes de code Java propre, nous construirons un interpréteur
complet pour Lox qui implémente chaque fonctionnalité du langage, exactement comme
nous l'avons spécifié. Les premiers chapitres travaillent de l'avant vers l'arrière
à travers les phases de l'interpréteur -- [scanning][], [parsing][], et
[évaluation de code][evaluating code]. Après cela, nous ajoutons des fonctionnalités
de langage une à la fois, faisant croître une simple calculatrice en un langage
de script complet.

[scanning]: scanning.html
[parsing]: parsing-expressions.html
[evaluating code]: evaluating-expressions.html
