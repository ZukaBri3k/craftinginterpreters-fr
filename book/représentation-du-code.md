> Pour les habitants d'un bois, presque chaque espèce d'arbre a sa voix aussi bien que
> son apparence.
> <cite>Thomas Hardy, <em>Under the Greenwood Tree</em></cite>

Dans le [dernier chapitre][scanning], nous avons pris le code source brut sous forme de chaîne et l'avons transformé en une représentation de niveau légèrement supérieur : une série de tokens. Le parseur que nous écrirons dans le [prochain chapitre][parsing] prendra ces tokens et les transformera encore une fois, en une représentation encore plus riche et plus complexe.

[scanning]: scanning.html
[parsing]: parsing-expressions.html

Avant de pouvoir produire cette représentation, nous devons la définir. C'est le sujet de ce chapitre. En chemin, nous <span name="boring">couvrirons</span> un peu de théorie autour des grammaires formelles, sentirons la différence entre la programmation fonctionnelle et orientée objet, passerons en revue quelques patrons de conception, et ferons un peu de métaprogrammation.

<aside name="boring">

J'étais tellement inquiet que ce soit l'un des chapitres les plus ennuyeux du livre que j'ai continué à y fourrer des idées amusantes jusqu'à ce que je n'aie plus de place.

</aside>

Avant de faire tout cela, concentrons-nous sur l'objectif principal -- une représentation pour le code. Elle devrait être simple à produire pour le parseur et facile à consommer pour l'interpréteur. Si vous n'avez pas encore écrit de parseur ou d'interpréteur, ces exigences ne sont pas exactement éclairantes. Peut-être que votre intuition peut aider. Que fait votre cerveau quand vous jouez le rôle d'un interpréteur _humain_ ? Comment évaluez-vous mentalement une expression arithmétique comme celle-ci :

```lox
1 + 2 * 3 - 4
```

Parce que vous comprenez l'ordre des opérations -- le vieux truc "PEMDAS" -- vous savez que la multiplication est évaluée avant l'addition ou la soustraction. Une façon de visualiser cette précédence est d'utiliser un arbre. Les nœuds feuilles sont des nombres, et les nœuds intérieurs sont des opérateurs avec des branches pour chacun de leurs opérandes.

[sally]: https://en.wikipedia.org/wiki/Order_of_operations#Mnemonics

Pour évaluer un nœud arithmétique, vous devez connaître les valeurs numériques de ses sous-arbres, donc vous devez évaluer ceux-là d'abord. Cela signifie travailler des feuilles jusqu'à la racine -- un parcours _post-ordre_ :

<span name="tree-steps"></span>

<img src="image/representing-code/tree-evaluate.png" alt="Évaluation de l'arbre du bas vers le haut." />

<aside name="tree-steps">

A. En commençant avec l'arbre complet, évaluez l'opération la plus basse, `2 * 3`.

B. Maintenant nous pouvons évaluer le `+`.

C. Ensuite, le `-`.

D. La réponse finale.

</aside>

Si je vous donnais une expression arithmétique, vous pourriez dessiner l'un de ces arbres assez facilement. Étant donné un arbre, vous pouvez l'évaluer sans transpirer. Il semble donc intuitivement qu'une représentation viable de notre code soit un <span name="only">arbre</span> qui correspond à la structure grammaticale -- l'imbrication des opérateurs -- du langage.

<aside name="only">

Cela ne veut pas dire qu'un arbre est la _seule_ représentation possible de notre code. Dans la [Partie III][], nous générerons du bytecode, une autre représentation qui n'est pas aussi conviviale pour les humains mais qui est plus proche de la machine.

[part iii]: a-bytecode-virtual-machine.html

</aside>

Nous devons être plus précis sur ce qu'est cette grammaire alors. Comme les grammaires lexicales dans le dernier chapitre, il y a une tonne de théorie autour des grammaires syntaxiques. Nous entrons dans cette théorie un peu plus que nous ne l'avons fait lors de l'analyse lexicale parce qu'il s'avère que c'est un outil utile pour une grande partie de l'interpréteur. Nous commençons par monter d'un niveau dans la [hiérarchie de Chomsky][]...

[chomsky hierarchy]: https://en.wikipedia.org/wiki/Chomsky_hierarchy

## Grammaires non contextuelles

Dans le dernier chapitre, le formalisme que nous avons utilisé pour définir la grammaire lexicale -- les règles pour comment les caractères sont regroupés en tokens -- s'appelait un _langage régulier_. C'était bien pour notre scanner, qui émet une séquence plate de tokens. Mais les langages réguliers ne sont pas assez puissants pour gérer des expressions qui peuvent s'imbriquer arbitrairement profondément.

Nous avons besoin d'un plus gros marteau, et ce marteau est une **grammaire non contextuelle** (**GNC**). C'est l'outil le plus lourd suivant dans la caisse à outils des **[grammaires formelles][]**. Une grammaire formelle prend un ensemble de pièces atomiques qu'elle appelle son "alphabet". Ensuite, elle définit un ensemble (généralement infini) de "chaînes" qui sont "dans" la grammaire. Chaque chaîne est une séquence de "lettres" de l'alphabet.

[formal grammars]: https://en.wikipedia.org/wiki/Formal_grammar

J'utilise tous ces guillemets parce que les termes deviennent un peu confus quand vous passez des grammaires lexicales aux grammaires syntaxiques. Dans la grammaire de notre scanner, l'alphabet consiste en des caractères individuels et les chaînes sont les lexèmes valides -- grosso modo les "mots". Dans la grammaire syntaxique dont nous parlons maintenant, nous sommes à un niveau de granularité différent. Maintenant chaque "lettre" dans l'alphabet est un token entier et une "chaîne" est une séquence de _tokens_ -- une expression entière.

Ouf. Peut-être qu'un tableau aidera :

<table>
<thead>
<tr>
  <td>Terminologie</td>
  <td></td>
  <td>Grammaire lexicale</td>
  <td>Grammaire syntaxique</td>
</tr>
</thead>
<tbody>
<tr>
  <td>L'&ldquo;alphabet&rdquo; est<span class="ellipse">&thinsp;.&thinsp;.&thinsp;.</span></td>
  <td>&rarr;&ensp;</td>
  <td>Caractères</td>
  <td>Tokens</td>
</tr>
<tr>
  <td>Une &ldquo;chaîne&rdquo; est<span class="ellipse">&thinsp;.&thinsp;.&thinsp;.</span></td>
  <td>&rarr;&ensp;</td>
  <td>Lexème ou token</td>
  <td>Expression</td>
</tr>
<tr>
  <td>C'est implémenté par le<span class="ellipse">&thinsp;.&thinsp;.&thinsp;.</span></td>
  <td>&rarr;&ensp;</td>
  <td>Scanner</td>
  <td>Parseur</td>
</tr>
</tbody>
</table>

Le travail d'une grammaire formelle est de spécifier quelles chaînes sont valides et lesquelles ne le sont pas. Si nous définissions une grammaire pour des phrases en anglais, "eggs are tasty for breakfast" serait dans la grammaire, mais "tasty breakfast for are eggs" ne le serait probablement pas.

### Règles pour les grammaires

Comment écrivons-nous une grammaire qui contient un nombre infini de chaînes valides ? Nous ne pouvons évidemment pas toutes les lister. Au lieu de cela, nous créons un ensemble fini de règles. Vous pouvez penser à elles comme un jeu auquel vous pouvez "jouer" dans l'une de deux directions.

Si vous commencez avec les règles, vous pouvez les utiliser pour _générer_ des chaînes qui sont dans la grammaire. Les chaînes créées de cette façon sont appelées des **dérivations** parce que chacune est _dérivée_ des règles de la grammaire. À chaque étape du jeu, vous choisissez une règle et suivez ce qu'elle vous dit de faire. La plupart du jargon autour des grammaires formelles vient du fait de les jouer dans cette direction. Les règles sont appelées **productions** parce qu'elles _produisent_ des chaînes dans la grammaire.

Chaque production dans une grammaire non contextuelle a une **tête** -- son <span name="name">nom</span> -- et un **corps**, qui décrit ce qu'elle génère. Dans sa forme pure, le corps est simplement une liste de symboles. Les symboles viennent en deux saveurs délectables :

<aside name="name">

Restreindre les têtes à un seul symbole est une caractéristique qui définit les grammaires non contextuelles. Des formalismes plus puissants comme les **[grammaires non restreintes][]** autorisent une séquence de symboles dans la tête aussi bien que dans le corps.

[unrestricted grammars]: https://en.wikipedia.org/wiki/Unrestricted_grammar

</aside>

- Un **terminal** est une lettre de l'alphabet de la grammaire. Vous pouvez le voir comme une valeur littérale. Dans la grammaire syntaxique que nous définissons, les terminaux sont des lexèmes individuels -- des tokens venant du scanner comme `if` ou `1234`.

    On les appelle "terminaux", dans le sens de "point final" parce qu'ils ne mènent à aucun autre "coup" dans le jeu. Vous produisez simplement ce symbole unique.

- Un **non-terminal** est une référence nommée à une autre règle dans la grammaire. Cela signifie "joue cette règle et insère quoi qu'elle produise ici". De cette façon, la grammaire se compose.

Il y a un dernier raffinement : vous pouvez avoir plusieurs règles avec le même nom. Lorsque vous atteignez un non-terminal avec ce nom, vous êtes autorisé à choisir n'importe laquelle des règles pour lui, celle qui vous plaît.

Pour rendre cela concret, nous avons besoin d'une <span name="turtles">façon</span> d'écrire ces règles de production. Les gens ont essayé de cristalliser la grammaire depuis l'_Ashtadhyayi_ de Pāṇini, qui a codifié la grammaire sanskrite il y a seulement quelques milliers d'années. Peu de progrès ont eu lieu jusqu'à ce que John Backus et compagnie aient besoin d'une notation pour spécifier ALGOL 58 et inventent la [**forme de Backus-Naur**][bnf] (**BNF**). Depuis lors, presque tout le monde utilise une variante de BNF, ajustée à ses propres goûts.

[bnf]: https://en.wikipedia.org/wiki/Backus%E2%80%93Naur_form

J'ai essayé de trouver quelque chose de propre. Chaque règle est un nom, suivi d'une flèche (`→`), suivi d'une séquence de symboles, et se terminant finalement par un point-virgule (`;`). Les terminaux sont des chaînes entre guillemets, et les non-terminaux sont des mots en minuscules.

<aside name="turtles">

Oui, nous avons besoin de définir une syntaxe à utiliser pour les règles qui définissent notre syntaxe. Devrions-nous spécifier cette _métasyntaxe_ aussi ? Quelle notation utilisons-nous pour _elle_ ? C'est des langages jusqu'en bas !

</aside>

En utilisant cela, voici une grammaire pour les menus du <span name="breakfast">petit-déjeuner</span> :

<aside name="breakfast">

Oui, je vais vraiment utiliser des exemples de petit-déjeuner tout au long de ce livre. Désolé.

</aside>

```ebnf
breakfast  → protein "with" breakfast "on the side" ;
breakfast  → protein ;
breakfast  → bread ;

protein    → crispiness "crispy" "bacon" ;
protein    → "sausage" ;
protein    → cooked "eggs" ;

crispiness → "really" ;
crispiness → "really" crispiness ;

cooked     → "scrambled" ;
cooked     → "poached" ;
cooked     → "fried" ;

bread      → "toast" ;
bread      → "biscuits" ;
bread      → "English muffin" ;
```

Nous pouvons utiliser cette grammaire pour générer des petits-déjeuners aléatoires. Jouons un tour et voyons comment ça marche. Par une convention séculaire, le jeu commence avec la première règle dans la grammaire, ici `breakfast`. Il y a trois productions pour celle-ci, et nous choisissons au hasard la première. Notre chaîne résultante ressemble à :

```text
protein "with" breakfast "on the side"
```

Nous avons besoin d'étendre ce premier non-terminal, `protein`, donc nous choisissons une production pour lui. Choisissons :

```ebnf
protein → cooked "eggs" ;
```

Ensuite, nous avons besoin d'une production pour `cooked`, et donc nous choisissons `"poached"`. C'est un terminal, donc nous l'ajoutons. Maintenant notre chaîne ressemble à :

```text
"poached" "eggs" "with" breakfast "on the side"
```

Le prochain non-terminal est `breakfast` à nouveau. La première production `breakfast` que nous avons choisie fait référence récursivement à la règle `breakfast`. La récursion dans la grammaire est un bon signe que le langage défini est non contextuel au lieu de régulier. En particulier, la récursion où le non-terminal récursif a des productions des <span name="nest">deux</span> côtés implique que le langage n'est pas régulier.

<aside name="nest">

Imaginez que nous ayons étendu récursivement la règle `breakfast` ici plusieurs fois, comme "bacon with bacon with bacon with..." Pour compléter la chaîne correctement, nous avons besoin d'ajouter un nombre _égal_ de bouts "on the side" à la fin. Suivre le nombre de parties finales requises est au-delà des capacités d'une grammaire régulière. Les grammaires régulières peuvent exprimer la _répétition_, mais elles ne peuvent pas _compter_ combien de répétitions il y a, ce qui est nécessaire pour s'assurer que la chaîne a le même nombre de parties `with` et `on the side`.

</aside>

Nous pourrions continuer à choisir la première production pour `breakfast` encore et encore produisant toute sorte de petits-déjeuners comme "bacon with sausage with scrambled eggs with bacon..." Nous ne le ferons pas cependant. Cette fois nous choisirons `bread`. Il y a trois règles pour cela, chacune contenant seulement un terminal. Nous choisirons "English muffin".

Avec cela, chaque non-terminal dans la chaîne a été étendu jusqu'à ce qu'il ne contienne finalement que des terminaux et nous nous retrouvons avec :

<img src="image/representing-code/breakfast.png" alt='"Jouer" la grammaire pour générer une chaîne.' />

Ajoutez du jambon et de la sauce Hollandaise, et vous avez des œufs Bénédicte.

Chaque fois que nous tombions sur une règle qui avait plusieurs productions, nous en choisissions juste une arbitrairement. C'est cette flexibilité qui permet à un petit nombre de règles de grammaire d'encoder un ensemble combinatoirement plus grand de chaînes. Le fait qu'une règle puisse se référer à elle-même -- directement ou indirectement -- augmente encore cela, nous laissant emballer un nombre infini de chaînes dans une grammaire finie.

### Améliorer notre notation

Fourrer un ensemble infini de chaînes dans une poignée de règles est assez fantastique, mais allons plus loin. Notre notation fonctionne, mais elle est fastidieuse. Donc, comme tout bon concepteur de langage, nous saupoudrerons un peu de sucre syntaxique dessus -- une notation de commodité supplémentaire. En plus des terminaux et des non-terminaux, nous autoriserons quelques autres types d'expressions dans le corps d'une règle :

- Au lieu de répéter le nom de la règle chaque fois que nous voulons ajouter une autre production pour elle, nous autoriserons une série de productions séparées par un pipe (`|`).

    ```ebnf
    bread → "toast" | "biscuits" | "English muffin" ;
    ```

- De plus, nous autoriserons les parenthèses pour le groupement et ensuite autoriserons `|` à l'intérieur pour sélectionner une option parmi une série au milieu d'une production.

    ```ebnf
    protein → ( "scrambled" | "poached" | "fried" ) "eggs" ;
    ```

- Utiliser la récursion pour supporter des séquences répétées de symboles a une certaine <span name="purity">pureté</span> attirante, mais c'est un peu une corvée de faire une sous-règle nommée séparée chaque fois que nous voulons boucler. Donc, nous utilisons aussi un suffixe `*` pour permettre au symbole ou groupe précédent d'être répété zéro ou plusieurs fois.

    ```ebnf
    crispiness → "really" "really"* ;
    ```

<aside name="purity">

C'est comme ça que le langage de programmation Scheme fonctionne. Il n'a aucune fonctionnalité de boucle intégrée du tout. Au lieu de cela, _toute_ répétition est exprimée en termes de récursion.

</aside>

- Un suffixe `+` est similaire, mais exige que la production précédente apparaisse au moins une fois.

    ```ebnf
    crispiness → "really"+ ;
    ```

- Un suffixe `?` est pour une production optionnelle. La chose avant elle peut apparaître zéro ou une fois, mais pas plus.

    ```ebnf
    breakfast → protein ( "with" breakfast "on the side" )? ;
    ```

Avec toutes ces gentillesses syntaxiques, notre grammaire de petit-déjeuner se condense en :

```ebnf
breakfast → protein ( "with" breakfast "on the side" )?
          | bread ;

protein   → "really"+ "crispy" "bacon"
          | "sausage"
          | ( "scrambled" | "poached" | "fried" ) "eggs" ;

bread     → "toast" | "biscuits" | "English muffin" ;
```

Pas trop mal, j'espère. Si vous êtes habitué à grep ou à utiliser des [expressions régulières][regex] dans votre éditeur de texte, la plupart de la ponctuation devrait être familière. La principale différence est que les symboles ici représentent des tokens entiers, pas des caractères uniques.

[regex]: https://en.wikipedia.org/wiki/Regular_expression#Standards

Nous utiliserons cette notation tout au long du reste du livre pour décrire précisément la grammaire de Lox. En travaillant sur des langages de programmation, vous découvrirez que les grammaires non contextuelles (utilisant ceci ou [EBNF][] ou une autre notation) vous aident à cristalliser vos idées informelles de conception de syntaxe. Elles sont aussi un support pratique pour communiquer avec d'autres hackers de langage à propos de la syntaxe.

[ebnf]: https://en.wikipedia.org/wiki/Extended_Backus%E2%80%93Naur_form

Les règles et productions que nous définissons pour Lox sont aussi notre guide pour la structure de données en arbre que nous allons implémenter pour représenter le code en mémoire. Avant de pouvoir faire cela, nous avons besoin d'une vraie grammaire pour Lox, ou au moins assez pour nous permettre de commencer.

### Une grammaire pour les expressions Lox

Dans le chapitre précédent, nous avons fait toute la grammaire lexicale de Lox d'un seul coup. Chaque mot-clé et morceau de ponctuation est là. La grammaire syntaxique est plus grande, et ce serait vraiment ennuyeux de parcourir le tout avant que nous ayons réellement notre interpréteur en marche.

Au lieu de cela, nous traiterons un sous-ensemble du langage dans les deux prochains chapitres. Une fois que nous aurons ce mini-langage représenté, parsé et interprété, les chapitres ultérieurs ajouteront progressivement de nouvelles fonctionnalités, y compris la nouvelle syntaxe. Pour l'instant, nous allons nous soucier uniquement d'une poignée d'expressions :

- **Littéraux.** Nombres, chaînes, Booléens, et `nil`.

- **Expressions unaires.** Un préfixe `!` pour effectuer un non logique, et `-` pour nier un nombre.

- **Expressions binaires.** Les opérateurs arithmétiques infixes (`+`, `-`, `*`, `/`) et logiques (`==`, `!=`, `<`, `<=`, `>`, `>=`) que nous connaissons et aimons.

- **Parenthèses.** Une paire de `(` et `)` enroulée autour d'une expression.

Cela nous donne assez de syntaxe pour des expressions comme :

```lox
1 - (2 * 3) < 4 == false
```

En utilisant notre nouvelle notation bien pratique, voici une grammaire pour ceux-là :

```ebnf
expression     → literal
               | unary
               | binary
               | grouping ;

literal        → NUMBER | STRING | "true" | "false" | "nil" ;
grouping       → "(" expression ")" ;
unary          → ( "-" | "!" ) expression ;
binary         → expression operator expression ;
operator       → "==" | "!=" | "<" | "<=" | ">" | ">="
               | "+"  | "-"  | "*" | "/" ;
```

Il y a un peu de <span name="play">métasyntaxe</span> supplémentaire ici. En plus des chaînes entre guillemets pour les terminaux qui matchent des lexèmes exacts, nous mettons en `MAJUSCULES` les terminaux qui sont un seul lexème dont la représentation textuelle peut varier. `NUMBER` est n'importe quel littéral numérique, et `STRING` est n'importe quel littéral de chaîne. Plus tard, nous ferons la même chose pour `IDENTIFIER`.

Cette grammaire est en fait ambiguë, ce que nous verrons quand nous arriverons à la parser. Mais c'est assez bon pour l'instant.

<aside name="play">

Si vous êtes enclin à le faire, essayez d'utiliser cette grammaire pour générer quelques expressions comme nous l'avons fait avec la grammaire du petit-déjeuner auparavant. Les expressions résultantes vous semblent-elles correctes ? Pouvez-vous lui faire générer quelque chose de faux comme `1 + / 3` ?

</aside>

## Implémenter des Arbres Syntaxiques

Finalement, nous arrivons à écrire un peu de code. Cette petite grammaire d'expression est notre squelette. Puisque la grammaire est récursive -- notez comment `grouping`, `unary`, et `binary` se réfèrent tous à `expression` -- notre structure de données formera un arbre. Puisque cette structure représente la syntaxe de notre langage, elle est appelée un <span name="ast">**arbre syntaxique**</span>.

<aside name="ast">

En particulier, nous définissons un **arbre syntaxique abstrait** (**ASA** ou **AST**). Dans un **arbre d'analyse**, chaque production de grammaire devient un nœud dans l'arbre. Un AST élide les productions qui ne sont pas nécessaires pour les phases ultérieures.

</aside>

Notre scanner utilisait une seule classe Token pour représenter toutes sortes de lexèmes. Pour distinguer les différentes sortes -- pensez au nombre `123` versus la chaîne `"123"` -- nous incluions un simple enum TokenType. Les arbres syntaxiques ne sont pas si <span name="token-data">homogènes</span>. Les expressions unaires ont un seul opérande, les expressions binaires en ont deux, et les littéraux n'en ont aucun.

Nous _pourrions_ écraser tout cela ensemble dans une seule classe Expression avec une liste arbitraire d'enfants. Certains compilateurs le font. Mais j'aime tirer le meilleur du système de types de Java. Donc nous définirons une classe de base pour les expressions. Ensuite, pour chaque type d'expression -- chaque production sous `expression` -- nous créons une sous-classe qui a des champs pour les non-terminaux spécifiques à cette règle. De cette façon, nous obtenons une erreur de compilation si nous essayons, disons, d'accéder au deuxième opérande d'une expression unaire.

<aside name="token-data">

Les tokens ne sont pas entièrement homogènes non plus. Les tokens pour les littéraux stockent la valeur, mais d'autres sortes de lexèmes n'ont pas besoin de cet état. J'ai vu des scanners qui utilisent différentes classes pour les littéraux et d'autres sortes de lexèmes, mais je me suis dit que je garderais les choses plus simples.

</aside>

Quelque chose comme ceci :

```java
package com.craftinginterpreters.lox;

abstract class Expr { // [expr]
  static class Binary extends Expr {
    Binary(Expr left, Token operator, Expr right) {
      this.left = left;
      this.operator = operator;
      this.right = right;
    }

    final Expr left;
    final Token operator;
    final Expr right;
  }

  // Other expressions...
}
```

<aside name="expr">

J'évite les abréviations dans mon code parce qu'elles font trébucher un lecteur qui ne sait pas ce qu'elles signifient. Mais dans les compilateurs que j'ai regardés, "Expr" et "Stmt" sont si omniprésents que je peux aussi bien commencer à vous y habituer maintenant.

</aside>

Expr est la classe de base dont héritent toutes les classes d'expression. Comme vous pouvez le voir avec `Binary`, les sous-classes sont imbriquées à l'intérieur. Il n'y a pas de besoin technique pour cela, mais cela nous laisse fourrer toutes les classes dans un seul fichier Java.

### Objets désorientés

Vous noterez que, tout comme la classe Token, il n'y a pas de méthodes ici. C'est une structure bête. Joliment typée, mais simplement un sac de données. Cela semble étrange dans un langage orienté objet comme Java. La classe ne devrait-elle pas _faire des trucs_ ?

Le problème est que ces classes d'arbres ne sont possédées par aucun domaine unique. Devraient-elles avoir des méthodes pour le parsing puisque c'est là que les arbres sont créés ? Ou l'interprétation puisque c'est là qu'ils sont consommés ? Les arbres enjambent la frontière entre ces territoires, ce qui signifie qu'ils ne sont vraiment possédés par _aucun_ des deux.

En fait, ces types existent pour permettre au parseur et à l'interpréteur de _communiquer_. Cela se prête à des types qui sont simplement des données sans comportement associé. Ce style est très naturel dans des langages fonctionnels comme Lisp et ML où _toutes_ les données sont séparées du comportement, mais cela semble bizarre en Java.

Les aficionados de la programmation fonctionnelle sautent en ce moment pour s'exclamer "Tu vois ! Les langages orientés objet sont un mauvais choix pour un interpréteur !" Je n'irai pas jusque-là. Vous vous souviendrez que le scanner lui-même était admirablement adapté à l'orientation objet. Il avait tout l'état mutable pour garder une trace d'où il était dans le code source, un ensemble bien défini de méthodes publiques, et une poignée d'assistants privés.

Mon sentiment est que chaque phase ou partie de l'interpréteur fonctionne bien dans un style orienté objet. Ce sont les structures de données qui circulent entre elles qui sont dépouillées de comportement.

### Métaprogrammer les arbres

Java peut exprimer des classes sans comportement, mais je ne dirais pas qu'il est particulièrement bon à ça. Onze lignes de code pour fourrer trois champs dans un objet est assez fastidieux, et quand nous aurons fini, nous aurons 21 de ces classes.

Je ne veux pas perdre votre temps ou mon encre à écrire tout cela. Vraiment, quelle est l'essence de chaque sous-classe ? Un nom, et une liste de champs typés. C'est tout. Nous sommes des hackers de langage intelligents, non ? <span name="automate">Automatisons</span>.

<aside name="automate">

Imaginez-moi faisant une danse de robot maladroite quand vous lisez ceci. "AU-TO-MA-TI-SONS."

</aside>

Au lieu d'écrire laborieusement à la main chaque définition de classe, déclaration de champ, constructeur et initialiseur, nous bricolerons un <span name="python">script</span> qui le fait pour nous. Il a une description de chaque type d'arbre -- son nom et ses champs -- et il affiche le code Java nécessaire pour définir une classe avec ce nom et cet état.

Ce script est une minuscule application en ligne de commande Java qui génère un fichier nommé "Expr.java" :

<aside name="python">

J'ai eu l'idée de scripter les classes d'arbre syntaxique de Jim Hugunin, créateur de Jython et IronPython.

Un vrai langage de script serait un meilleur choix pour cela que Java, mais j'essaie de ne pas vous jeter trop de langages à la figure.

</aside>

^code generate-ast

Notez que ce fichier est dans un paquetage différent, `.tool` au lieu de `.lox`. Ce script ne fait pas partie de l'interpréteur lui-même. C'est un outil que _nous_, les gens qui hackent l'interpréteur, exécutons nous-mêmes pour générer les classes d'arbre syntaxique. Quand c'est fini, nous traitons "Expr.java" comme n'importe quel autre fichier dans l'implémentation. Nous automatisons simplement la façon dont ce fichier est rédigé.

Pour générer les classes, il a besoin d'avoir une description de chaque type et de ses champs.

^code call-define-ast (1 before, 1 after)

Pour la concision, j'ai coincé les descriptions des types d'expression dans des chaînes. Chacune est le nom de la classe suivi par `:` et la liste des champs, séparés par des virgules. Chaque champ a un type et un nom.

La première chose que `defineAst()` doit faire est de sortir la classe de base Expr.

^code define-ast

Quand nous appelons ceci, `baseName` est "Expr", qui est à la fois le nom de la classe et le nom du fichier qu'il produit. Nous passons ceci comme argument au lieu de coder en dur le nom parce que nous ajouterons une famille séparée de classes plus tard pour les instructions.

À l'intérieur de la classe de base, nous définissons chaque sous-classe.

^code nested-classes (2 before, 1 after)

<aside name="robust">

Ce n'est pas le code de manipulation de chaînes le plus élégant du monde, mais c'est bon. Il ne s'exécute que sur l'ensemble exact de définitions de classes que nous lui donnons. La robustesse n'est pas une priorité.

</aside>

Ce code, à son tour, appelle :

^code define-type

Et voilà. Tout ce superbe code standard Java est fait. Il déclare chaque champ dans le corps de la classe. Il définit un constructeur pour la classe avec des paramètres pour chaque champ et les initialise dans le corps.

Compilez et lancez ce programme Java maintenant et il [crache][longer] un nouveau fichier ".java" contenant quelques douzaines de lignes de code. Ce fichier est sur le point de devenir encore plus long.

<aside name="longer">

L'[Annexe II][] contient le code généré par ce script une fois que nous avons fini d'implémenter jlox et défini tous ses nœuds d'arbre syntaxique.

[appendix ii]: appendix-ii.html

</aside>

## Travailler avec des Arbres

Mettez votre chapeau d'imagination un instant. Même si nous n'y sommes pas encore, considérez ce que l'interpréteur fera avec les arbres syntaxiques. Chaque type d'expression dans Lox se comporte différemment à l'exécution. Cela signifie que l'interpréteur a besoin de sélectionner un morceau de code différent pour gérer chaque type d'expression. Avec les tokens, nous pouvons simplement switcher sur le TokenType. Mais nous n'avons pas un enum "type" pour les arbres syntaxiques, juste une classe Java séparée pour chacun.

Nous pourrions écrire une longue chaîne de tests de type :

```java
if (expr instanceof Expr.Binary) {
  // ...
} else if (expr instanceof Expr.Grouping) {
  // ...
} else // ...
```

Mais tous ces tests de type séquentiels sont lents. Les types d'expression dont les noms sont alphabétiquement plus tard prendraient plus de temps à s'exécuter parce qu'ils tomberaient à travers plus de cas `if` avant de trouver le bon type. Ce n'est pas mon idée d'une solution élégante.

Nous avons une famille de classes et nous avons besoin d'associer un morceau de comportement avec chacune. La solution naturelle dans un langage orienté objet comme Java est de mettre ces comportements dans des méthodes sur les classes elles-mêmes. Nous pourrions ajouter une méthode abstraite <span name="interpreter-pattern">`interpret()`</span> sur Expr que chaque sous-classe implémenterait alors pour s'interpréter elle-même.

<aside name="interpreter-pattern">

Cette chose exacte est littéralement appelée le ["Patron Interpréteur"][interp] dans _Design Patterns: Elements of Reusable Object-Oriented Software_, par Erich Gamma, et al.

[interp]: https://en.wikipedia.org/wiki/Interpreter_pattern

</aside>

Cela marche bien pour les petits projets, mais cela passe mal à l'échelle. Comme je l'ai noté avant, ces classes d'arbres enjambent quelques domaines. À tout le moins, le parseur et l'interpréteur vont tous deux tripatouiller avec elles. Comme [vous le verrez plus tard][resolution], nous avons besoin de faire une résolution de noms sur elles. Si notre langage était typé statiquement, nous aurions une passe de vérification de type.

[resolution]: resolving-and-binding.html

Si nous ajoutions des méthodes d'instance aux classes d'expression pour chacune de ces opérations, cela écraserait un tas de domaines différents ensemble. Cela viole la [séparation des préoccupations][] et mène à du code difficile à maintenir.

[separation of concerns]: https://en.wikipedia.org/wiki/Separation_of_concerns

### Le problème de l'expression

Ce problème est plus fondamental qu'il n'y paraît au premier abord. Nous avons une poignée de types, et une poignée d'opérations de haut niveau comme "interpréter". Pour chaque paire de type et d'opération, nous avons besoin d'une implémentation spécifique. Imaginez un tableau :

<img src="image/representing-code/table.png" alt="Un tableau où les lignes sont étiquetées avec les classes d'expression, et les colonnes sont des noms de fonctions." />

Les lignes sont les types, et les colonnes sont les opérations. Chaque cellule représente le morceau de code unique pour implémenter cette opération sur ce type.

Un langage orienté objet comme Java suppose que tout le code dans une ligne va naturellement ensemble. Il se figure que toutes les choses que vous faites avec un type sont probablement liées les unes aux autres, et le langage rend facile de les définir ensemble comme méthodes à l'intérieur de la même classe.

<img src="image/representing-code/rows.png" alt="Le tableau séparé en lignes pour chaque classe." />

Cela rend facile l'extension du tableau en ajoutant de nouvelles lignes. Définissez simplement une nouvelle classe. Aucun code existant n'a besoin d'être touché. Mais imaginez si vous voulez ajouter une nouvelle _opération_ -- une nouvelle colonne. En Java, cela signifie ouvrir chacune de ces classes existantes et y ajouter une méthode.

Les langages du paradigme fonctionnel de la famille <span name="ml">ML</span> retournent cela. Là, vous n'avez pas de classes avec des méthodes. Les types et les fonctions sont totalement distincts. Pour implémenter une opération pour un certain nombre de types différents, vous définissez une seule fonction. Dans le corps de cette fonction, vous utilisez le _pattern matching_ (filtrage par motif) -- sorte de switch basé sur le type sous stéroïdes -- pour implémenter l'opération pour chaque type tout en un seul endroit.

<aside name="ml">

ML, abréviation de "métalangage", a été créé par Robin Milner et ses amis et forme l'une des branches principales dans le grand arbre généalogique des langages de programmation. Ses enfants incluent SML, Caml, OCaml, Haskell, et F#. Même Scala, Rust, et Swift portent une forte ressemblance.

Tout comme Lisp, c'est l'un de ces langages qui est si plein de bonnes idées que les concepteurs de langage aujourd'hui les redécouvrent encore plus de quarante ans plus tard.

</aside>

Cela rend trivial l'ajout de nouvelles opérations -- définissez simplement une autre fonction qui fait du pattern matching sur tous les types.

<img src="image/representing-code/columns.png" alt="Le tableau séparé en colonnes pour chaque fonction." />

Mais, inversement, ajouter un nouveau type est difficile. Vous devez revenir en arrière et ajouter un nouveau cas à tous les pattern matchings dans toutes les fonctions existantes.

Chaque style a un certain "grain". C'est ce que le nom du paradigme dit littéralement -- un langage orienté objet veut que vous _orientiez_ votre code le long des lignes de types. Un langage fonctionnel vous encourage au contraire à regrouper le code de chaque colonne dans une _fonction_.

Un tas de nerds intelligents en langage ont remarqué qu'aucun des deux styles ne rendait facile l'ajout _à la fois_ de lignes et de colonnes au <span name="multi">tableau</span>. Ils ont appelé cette difficulté le "problème de l'expression" parce que -- comme nous maintenant -- ils l'ont rencontré pour la première fois quand ils essayaient de trouver la meilleure façon de modéliser les nœuds d'arbre syntaxique d'expression dans un compilateur.

<aside name="multi">

Les langages avec _multiméthodes_, comme CLOS de Common Lisp, Dylan, et Julia supportent l'ajout facile à la fois de nouveaux types et d'opérations. Ce qu'ils sacrifient typiquement est soit la vérification statique de type, soit la compilation séparée.

</aside>

Les gens ont lancé toutes sortes de fonctionnalités de langage, de patrons de conception et d'astuces de programmation pour essayer d'abattre ce problème mais aucun langage parfait ne l'a encore achevé. En attendant, le mieux que nous puissions faire est d'essayer de choisir un langage dont l'orientation correspond aux coutures architecturales naturelles dans le programme que nous écrivons.

L'orientation objet fonctionne bien pour de nombreuses parties de notre interpréteur, mais ces classes d'arbres vont à l'encontre du grain de Java. Heureusement, il y a un patron de conception que nous pouvons mettre à profit ici.

### Le patron Visiteur

Le **patron Visiteur** est le patron le plus largement mal compris de tout _Design Patterns_, ce qui veut vraiment dire quelque chose quand vous regardez les excès d'architecture logicielle des deux dernières décennies.

Le problème commence avec la terminologie. Le patron n'a rien à voir avec "visiter", et la méthode "accept" dedans n'évoque aucune image utile non plus. Beaucoup pensent que le patron a à voir avec la traversée d'arbres, ce qui n'est pas le cas du tout. Nous _allons_ l'utiliser sur un ensemble de classes qui sont arborescentes, mais c'est une coïncidence. Comme vous le verrez, le patron fonctionne aussi bien sur un seul objet.

Le patron Visiteur consiste vraiment à approximer le style fonctionnel au sein d'un langage POO. Il nous permet d'ajouter facilement de nouvelles colonnes à ce tableau. Nous pouvons définir tout le comportement pour une nouvelle opération sur un ensemble de types en un seul endroit, sans avoir à toucher aux types eux-mêmes. Il fait cela de la même manière que nous résolvons presque tous les problèmes en informatique : en ajoutant une couche d'indirection.

Avant de l'appliquer à nos classes Expr auto-générées, parcourons un exemple plus simple. Disons que nous avons deux sortes de pâtisseries : des <span name="beignet">beignets</span> et des crullers.

<aside name="beignet">

Un beignet (prononcé "bè-nié") est une pâtisserie frite de la même famille que les donuts. Quand les Français ont colonisé l'Amérique du Nord dans les années 1700, ils ont apporté les beignets avec eux. Aujourd'hui, aux US, ils sont le plus fortement associés à la cuisine de la Nouvelle-Orléans.

Ma façon préférée de les consommer est tout juste sortis de la friteuse au Café du Monde, empilés haut sous le sucre en poudre, et arrosés d'une tasse de café au lait pendant que je regarde les touristes tituber autour en essayant de secouer leur gueule de bois des festivités de la nuit précédente.

</aside>

^code pastries (no location)

Nous voulons être capables de définir de nouvelles opérations de pâtisserie -- les cuire, les manger, les décorer, etc. -- sans avoir à ajouter une nouvelle méthode à chaque classe à chaque fois. Voici comment nous faisons. D'abord, nous définissons une interface séparée.

^code pastry-visitor (no location)

<aside name="overload">

Dans _Design Patterns_, ces deux méthodes sont confusément nommées `visit()`, et elles comptent sur la surcharge pour les distinguer. Cela conduit certains lecteurs à penser que la bonne méthode visit est choisie _à l'exécution_ basée sur son type de paramètre. Ce n'est pas le cas. Contrairement à la réécriture (overriding), la surcharge (overloading) est dépêchée statiquement au moment de la compilation.

Utiliser des noms distincts pour chaque méthode rend le dispatch plus évident, et vous montre aussi comment appliquer ce patron dans des langages qui ne supportent pas la surcharge.

</aside>

Chaque opération qui peut être effectuée sur des pâtisseries est une nouvelle classe qui implémente cette interface. Elle a une méthode concrète pour chaque type de pâtisserie. Cela garde le code pour l'opération sur les deux types tout niché confortablement ensemble dans une classe.

Étant donné une certaine pâtisserie, comment la router vers la bonne méthode sur le visiteur en fonction de son type ? Le polymorphisme à la rescousse ! Nous ajoutons cette méthode à Pastry :

^code pastry-accept (1 before, 1 after, no location)

Chaque sous-classe l'implémente.

^code beignet-accept (1 before, 1 after, no location)

Et :

^code cruller-accept (1 before, 1 after, no location)

Pour effectuer une opération sur une pâtisserie, nous appelons sa méthode `accept()` et passons le visiteur pour l'opération que nous voulons exécuter. La pâtisserie -- l'implémentation de réécriture de `accept()` de la sous-classe spécifique -- se retourne et appelle la méthode visit appropriée sur le visiteur et lui passe _elle-même_.

C'est le cœur du truc juste là. Cela nous permet d'utiliser le dispatch polymorphique sur les classes de _pâtisserie_ pour sélectionner la méthode appropriée sur la classe _visiteur_. Dans le tableau, chaque classe de pâtisserie est une ligne, mais si vous regardez toutes les méthodes pour un seul visiteur, elles forment une _colonne_.

<img src="image/representing-code/visitor.png" alt="Maintenant toutes les cellules pour une opération font partie de la même classe, le visiteur." />

Nous avons ajouté une méthode `accept()` à chaque classe, et nous pouvons l'utiliser pour autant de visiteurs que nous voulons sans jamais avoir à toucher aux classes de pâtisserie à nouveau. C'est un patron intelligent.

### Visiteurs pour les expressions

OK, tissons-le dans nos classes d'expression. Nous allons aussi <span name="context">affiner</span> le patron un peu. Dans l'exemple de la pâtisserie, les méthodes visit et `accept()` ne renvoient rien. En pratique, les visiteurs veulent souvent définir des opérations qui produisent des valeurs. Mais quel type de retour devrait avoir `accept()` ? Nous ne pouvons pas supposer que chaque classe de visiteur veuille produire le même type, donc nous utiliserons des génériques pour laisser chaque implémentation remplir un type de retour.

<aside name="context">

Un autre raffinement courant est un paramètre "contexte" supplémentaire qui est passé aux méthodes visit et ensuite renvoyé à travers comme paramètre à `accept()`. Cela permet aux opérations de prendre un paramètre supplémentaire. Les visiteurs que nous définirons dans le livre n'ont pas besoin de cela, donc je l'ai omis.

</aside>

D'abord, nous définissons l'interface visiteur. Encore une fois, nous l'imbriquons à l'intérieur de la classe de base pour pouvoir tout garder dans un fichier.

^code call-define-visitor (2 before, 1 after)

Cette fonction génère l'interface visiteur.

^code define-visitor

Ici, nous itérons à travers toutes les sous-classes et déclarons une méthode visit pour chacune. Quand nous définirons de nouveaux types d'expression plus tard, cela les inclura automatiquement.

À l'intérieur de la classe de base, nous définissons la méthode abstraite `accept()`.

^code base-accept-method (2 before, 1 after)

Enfin, chaque sous-classe implémente cela et appelle la bonne méthode visit pour son propre type.

^code accept-method (1 before, 2 after)

Et voilà. Maintenant nous pouvons définir des opérations sur les expressions sans avoir à trifouiller avec les classes ou notre script générateur. Compilez et lancez ce script générateur pour sortir un fichier "Expr.java" mis à jour. Il contient une interface Visitor générée et un ensemble de classes de nœud d'expression qui supportent le patron Visiteur en l'utilisant.

Avant de terminer ce chapitre décousu, implémentons cette interface Visitor et voyons le patron en action.

## Un Pretty Printer (Pas Très) Joli

Quand nous déboguons notre parseur et interpréteur, c'est souvent utile de regarder un arbre syntaxique parsé et de s'assurer qu'il a la structure que nous attendons. Nous pourrions l'inspecter dans le débogueur, mais cela peut être une corvée.

Au lieu de cela, nous aimerions du code qui, étant donné un arbre syntaxique, produit une représentation en chaîne non ambiguë de celui-ci. Convertir un arbre en chaîne est une sorte d'opposé d'un parseur, et est souvent appelé "pretty printing" quand le but est de produire une chaîne de texte qui est une syntaxe valide dans le langage source.

Ce n'est pas notre but ici. Nous voulons que la chaîne montre très explicitement la structure d'imbrication de l'arbre. Un printer qui renverrait `1 + 2 * 3` n'est pas super utile si ce que nous essayons de déboguer est de savoir si la précédence des opérateurs est gérée correctement. Nous voulons savoir si le `+` ou le `*` est au sommet de l'arbre.

À cette fin, la représentation en chaîne que nous produisons ne va pas être de la syntaxe Lox. Au lieu de cela, elle ressemblera beaucoup à, eh bien, du Lisp. Chaque expression est explicitement parenthésée, et toutes ses sous-expressions et tokens sont contenus là-dedans.

Étant donné un arbre syntaxique comme :

<img src="image/representing-code/expression.png" alt="Un exemple d'arbre syntaxique." />

Il produit :

```text
(* (- 123) (group 45.67))
```

Pas exactement "joli", mais cela montre l'imbrication et le groupement explicitement. Pour implémenter cela, nous définissons une nouvelle classe.

^code ast-printer

Comme vous pouvez le voir, elle implémente l'interface visiteur. Cela signifie que nous avons besoin de méthodes visit pour chaque type d'expression que nous avons jusqu'à présent.

^code visit-methods (2 before, 1 after)

Les expressions littérales sont faciles -- elles convertissent la valeur en chaîne avec une petite vérification pour gérer le `null` de Java remplaçant le `nil` de Lox. Les autres expressions ont des sous-expressions, donc elles utilisent cette méthode d'aide `parenthesize()` :

^code print-utilities

Elle prend un nom et une liste de sous-expressions et les enveloppe toutes dans des parenthèses, donnant une chaîne comme :

```text
(+ 1 2)
```

Notez qu'elle appelle `accept()` sur chaque sous-expression et se passe elle-même. C'est l'étape <span name="tree">récursive</span> qui nous permet d'afficher un arbre entier.

<aside name="tree">

Cette récursion est aussi la raison pour laquelle les gens pensent que le patron Visiteur lui-même a à voir avec des arbres.

</aside>

Nous n'avons pas encore de parseur, donc il est difficile de voir cela en action. Pour l'instant, nous allons bricoler une petite méthode `main()` qui instancie manuellement un arbre et l'affiche.

^code printer-main

Si nous avons tout fait juste, cela affiche :

```text
(* (- 123) (group 45.67))
```

Vous pouvez y aller et supprimer cette méthode. Nous n'en aurons pas besoin. Aussi, comme nous ajouterons de nouveaux types d'arbre syntaxique, je ne prendrai pas la peine de montrer les méthodes visit nécessaires pour eux dans AstPrinter. Si vous voulez (et que vous voulez que le compilateur Java ne vous crie pas dessus), allez-y et ajoutez-les vous-même. Cela sera utile dans le prochain chapitre quand nous commencerons à parser du code Lox en arbres syntaxiques. Ou, si vous ne tenez pas à maintenir AstPrinter, sentez-vous libre de la supprimer. Nous n'en aurons plus besoin.

<div class="challenges">

## Défis

1.  Plus tôt, j'ai dit que les formes `|`, `*`, et `+` que nous avons ajoutées à notre métasyntaxe de grammaire étaient juste du sucre syntaxique. Prenez cette grammaire :

    ```ebnf
    expr → expr ( "(" ( expr ( "," expr )* )? ")" | "." IDENTIFIER )+
         | IDENTIFIER
         | NUMBER
    ```

    Produisez une grammaire qui matche le même langage mais n'utilise aucun de ces sucres notationnels.

    _Bonus :_ Quel genre d'expression ce bout de grammaire encode-t-il ?

1.  Le patron Visiteur vous permet d'émuler le style fonctionnel dans un langage orienté objet. Concevez un patron complémentaire pour un langage fonctionnel. Il devrait vous permettre de regrouper toutes les opérations sur un type ensemble et vous permettre de définir de nouveaux types facilement.

    (SML ou Haskell serait idéal pour cet exercice, mais Scheme ou un autre Lisp marche aussi bien.)

1.  En [notation polonaise inverse][rpn] (NPI), les opérandes d'un opérateur arithmétique sont tous deux placés avant l'opérateur, donc `1 + 2` devient `1 2 +`. L'évaluation procède de gauche à droite. Les nombres sont poussés sur une pile implicite. Un opérateur arithmétique dépile les deux nombres du haut, effectue l'opération, et empile le résultat. Ainsi, ceci :

    ```lox
    (1 + 2) * (4 - 3)
    ```

    en NPI devient :

    ```lox
    1 2 + 4 3 - *
    ```

    Définissez une classe visiteur pour nos classes d'arbre syntaxique qui prend une expression, la convertit en NPI, et renvoie la chaîne résultante.

[rpn]: https://en.wikipedia.org/wiki/Reverse_Polish_notation

</div>
