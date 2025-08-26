> Les contes de fées sont plus vrais que vrais : non pas parce qu’ils nous disent que les dragons existent,  
> mais parce qu’ils nous disent que les dragons peuvent être vaincus.  
>
> <cite>G.K. Chesterton via Neil Gaiman, <em>Coraline</em></cite>

Je suis vraiment enthousiaste que nous entreprenions ce voyage ensemble. Ceci est un livre sur
l’implémentation d’interpréteurs pour des langages de programmation. C’est aussi un livre sur la manière de
concevoir un langage qui mérite d’être implémenté. C’est le livre que j’aurais aimé avoir quand j’ai commencé
à m’intéresser aux langages, et c’est le livre que j’écris dans ma <span
name="head">tête</span> depuis près d’une décennie.

<aside name="head">

À mes amis et à ma famille, désolé d’avoir été si distrait !

</aside>


Dans ces pages, nous allons parcourir pas à pas deux interpréteurs complets pour
un langage riche en fonctionnalités. Je pars du principe qu’il s’agit de votre première incursion dans les langages, donc
je couvrirai chaque concept et chaque ligne de code dont vous aurez besoin pour construire une implémentation de langage complète, utilisable et rapide.

Afin de caser deux implémentations complètes dans un seul livre sans qu’il ne se transforme
en cale-porte, ce texte est plus léger en théorie que d’autres. À mesure que nous construirons chaque
partie du système, je présenterai l’histoire et les concepts qui la sous-tendent. J’essaierai
de vous familiariser avec le jargon afin que, si jamais vous vous retrouvez à une
<span name="party">soirée cocktail</span> remplie de chercheurs en LP (langages de programmation),
vous soyez à l’aise.

<aside name="party">

Aussi étrange que cela puisse paraître, une situation dans laquelle je me suis retrouvé plusieurs fois.  
Vous ne croiriez pas combien certains d’entre eux peuvent boire.

</aside>


Mais nous allons surtout consacrer notre énergie cérébrale à faire en sorte que le langage démarre et fonctionne.  
Cela ne veut pas dire que la théorie n’est pas importante. Être capable de raisonner
de manière précise et <span name="formal">formelle</span> à propos de la syntaxe et de la sémantique est
une compétence vitale lorsqu’on travaille sur un langage. Mais, personnellement, j’apprends mieux en
faisant. J’ai du mal à me frayer un chemin à travers des paragraphes remplis de concepts abstraits et
à vraiment les assimiler. Mais si j’ai codé quelque chose, exécuté le code, et corrigé ses erreurs, alors je
*comprends*.

<aside name="formal">

Les systèmes de types statiques, en particulier, exigent un raisonnement formel rigoureux.  
Bidouiller un système de types donne la même impression que de démontrer un théorème en mathématiques.

Il s’avère que ce n’est pas une coïncidence. Dans la première moitié du siècle dernier, Haskell
Curry et William Alvin Howard ont montré qu’il s’agissait des deux faces d’une même pièce :
[le isomorphisme de Curry-Howard][].

[le isomorphisme de curry-howard]: https://en.wikipedia.org/wiki/Curry%E2%80%93Howard_correspondence

</aside>

C’est mon objectif pour vous. Je veux que vous repartiez avec une intuition solide de la manière dont un
langage réel vit et respire. J’espère que lorsque vous lirez d’autres livres plus théoriques par la suite,  
les concepts qu’ils présentent resteront fermement ancrés dans votre esprit, attachés à ce substrat tangible.


## Pourquoi apprendre tout ça ?

Chaque introduction de chaque livre sur les compilateurs semble avoir cette section.  
Je ne sais pas ce qu’il y a avec les langages de programmation qui provoque un tel doute existentiel.  
Je ne pense pas que les livres d’ornithologie s’inquiètent de justifier leur existence.  
Ils partent du principe que le lecteur aime les oiseaux et commencent à enseigner.  

Mais les langages de programmation sont un peu différents. J’imagine qu’il est vrai que les chances pour l’un de nous de créer un langage de programmation à usage général et largement populaire sont minces.  
Les concepteurs des langages les plus utilisés dans le monde pourraient tenir dans un minibus Volkswagen, même sans relever le toit escamotable.  
Si rejoindre ce groupe d’élite était la *seule* raison d’apprendre les langages, ce serait difficile à justifier. Heureusement, ce n’est pas le cas.  

### Les petits langages sont partout

Pour chaque langage généraliste réussi, il existe un millier de langages spécialisés qui réussissent.  
Nous avions l’habitude de les appeler « petits langages », mais l’inflation dans l’économie du jargon a conduit au nom de « langages spécifiques à un domaine ».  
Ce sont des pidgins conçus sur mesure pour une tâche précise. Pensez aux langages de script d’application, aux moteurs de templates, aux formats de balisage et aux fichiers de configuration.  

<span name="little"></span><img src="image/introduction/little-languages.png" alt="Une sélection aléatoire de petits langages." />

<aside name="little">

Une sélection aléatoire de quelques petits langages que vous pourriez rencontrer.  

</aside>


Presque chaque grand projet logiciel a besoin d’une poignée de ceux-ci. Quand c’est possible, il vaut mieux réutiliser un existant plutôt que de créer le vôtre.  
Une fois que vous prenez en compte la documentation, les débogueurs, le support dans les éditeurs, la coloration syntaxique et tout le reste, le faire vous-même devient une tâche ardue.  

Mais il y a encore de bonnes chances que vous vous retrouviez à devoir bricoler un parseur ou un autre outil lorsqu’il n’existe pas de bibliothèque adaptée à vos besoins.  
Même lorsque vous réutilisez une implémentation existante, vous finirez inévitablement par devoir la déboguer, la maintenir et plonger dans ses entrailles.  

### Les langages sont un excellent exercice

Les coureurs de fond s’entraînent parfois avec des poids attachés aux chevilles ou en haute altitude, là où l’air est raréfié.  
Quand ils s’en débarrassent ensuite, la nouvelle légèreté de leurs membres et l’air riche en oxygène leur permet de courir plus loin et plus vite.  

Implémenter un langage est un véritable test de compétence en programmation. Le code est complexe et critique en termes de performance.  
Vous devez maîtriser la récursivité, les tableaux dynamiques, les arbres, les graphes et les tables de hachage.  
Vous utilisez probablement des tables de hachage dans votre programmation quotidienne, mais les comprenez-vous *vraiment* ?  
Eh bien, après avoir construit les nôtres à partir de zéro, je vous garantis que oui.  

Même si je souhaite vous montrer qu’un interpréteur n’est pas aussi intimidant que vous pourriez le croire, en implémenter un correctement reste un défi.  
Relevez-le, et vous repartirez en meilleur programmeur, plus avisé sur votre utilisation des structures de données et des algorithmes dans votre travail quotidien.  

### Une raison de plus

Cette dernière raison est difficile pour moi à admettre, car elle me tient tellement à cœur.  
Depuis que j’ai appris à programmer enfant, j’ai toujours ressenti quelque chose de magique à propos des langages.  
Quand j’ai tapoté mes premiers programmes BASIC une touche à la fois, je ne pouvais pas concevoir comment BASIC *lui-même* était fait.  

Plus tard, le mélange d’admiration et de terreur sur le visage de mes camarades d’université quand ils parlaient de leur cours de compilateurs suffisait à me convaincre que les bidouilleurs de langages étaient d’une autre espèce d’humains — une sorte de sorciers ayant accès à des arts secrets.  

C’est une <span name="image">image</span> séduisante, mais qui a un côté plus sombre. *Moi*, je ne me sentais pas comme un sorcier, alors j’en venais à penser qu’il me manquait une qualité innée nécessaire pour rejoindre cette cabale.  
Bien que j’aie été fasciné par les langages depuis que je griffonnais des mots-clés inventés dans mon cahier d’école, il m’a fallu des décennies pour trouver le courage d’essayer réellement de les apprendre.  
Cette qualité « magique », ce sentiment d’exclusivité, m’excluait *moi*.  

<aside name="image">

Et ceux qui la pratiquent n’hésitent pas à renforcer cette image.  
Deux des textes fondateurs sur les langages de programmation affichent un [dragon][] et un [sorcier][] sur leur couverture.  

[dragon]: https://en.wikipedia.org/wiki/Compilers:_Principles,_Techniques,_and_Tools  
[sorcier]: https://mitpress.mit.edu/sites/default/files/sicp/index.html  

</aside>


Lorsque j’ai finalement commencé à assembler mes propres petits interpréteurs, j’ai vite appris que, bien sûr, il n’y a absolument aucune magie.  
Ce n’est que du code, et les personnes qui bidouillent les langages ne sont que des gens.  

Il *existe* quelques techniques que l’on ne rencontre pas souvent en dehors des langages, et certaines parties sont un peu difficiles.  
Mais pas plus difficiles que d’autres obstacles que vous avez déjà surmontés.  
J’espère que si vous vous êtes senti intimidé par les langages et que ce livre vous aide à surmonter cette peur, peut-être que je vous laisserai un tout petit peu plus courageux qu’auparavant.  

Et, qui sait, peut-être que vous *créerez* le prochain grand langage. Il faut bien que quelqu’un le fasse.  

## Comment le livre est organisé

Ce livre est divisé en trois parties. Vous lisez la première maintenant.  
C’est quelques chapitres pour vous orienter, vous apprendre un peu le jargon utilisé par les bidouilleurs de langages, et vous présenter Lox, le langage que nous allons implémenter.  

Chacune des deux autres parties construit un interpréteur Lox complet.  
Dans ces parties, chaque chapitre est structuré de la même manière. Le chapitre prend une seule fonctionnalité du langage, vous enseigne les concepts qui la sous-tendent, et vous guide dans son implémentation.  

Il m’a fallu pas mal d’essais et d’erreurs, mais j’ai réussi à découper les deux interpréteurs en sections de taille chapitre qui s’appuient sur les chapitres précédents sans nécessiter ceux qui suivent.  
Dès le tout premier chapitre, vous aurez un programme fonctionnel que vous pouvez exécuter et tester.  
Au fil des chapitres, il devient de plus en plus complet jusqu’à ce que vous ayez finalement un langage complet.  

En plus d’une prose anglaise abondante et captivante, les chapitres ont quelques autres facettes délicieuses :  

### Le code

Nous sommes là pour *fabriquer* des interpréteurs, donc ce livre contient du vrai code.  
Chaque ligne de code nécessaire est incluse, et chaque extrait vous indique où l’insérer dans votre implémentation toujours croissante.  

Beaucoup d’autres livres sur les langages et implémentations de langages utilisent des outils comme [Lex][] et <span name="yacc">[Yacc][]</span>, les soi-disant **compiler-compilers**, qui génèrent automatiquement certains fichiers source d’une implémentation à partir d’une description de plus haut niveau.  
Il y a des avantages et des inconvénients à ces outils, et des opinions fortes — certains diraient même des convictions religieuses — des deux côtés.  

<aside name="yacc">

Yacc est un outil qui prend un fichier de grammaire et produit un fichier source pour un compilateur, c’est donc un peu comme un « compilateur » qui produit un compilateur, d’où le terme « compiler-compiler ».  

Yacc n’a pas été le premier du genre, ce qui explique son nom — *Yet Another* Compiler-Compiler.  
Un outil similaire ultérieur est [Bison][], nommé en jeu de mots sur la prononciation de Yacc comme « yak ».  

<img src="image/introduction/yak.png" alt="Un yak." />

Si vous trouvez toutes ces petites auto-références et jeux de mots charmants et amusants, vous vous sentirez à l’aise ici.  
Sinon, eh bien, peut-être que le sens de l’humour des nerds de langages est un goût acquis.  

</aside>


Nous nous abstiendrons de les utiliser ici. Je veux m’assurer qu’il n’y ait pas de recoins sombres où magie et confusion pourraient se cacher, donc nous écrirons tout à la main.  
Comme vous le verrez, ce n’est pas aussi terrible que cela en a l’air, et cela signifie que vous comprendrez vraiment chaque ligne de code et comment les deux interpréteurs fonctionnent.  

[lex]: https://en.wikipedia.org/wiki/Lex_(software)  
[yacc]: https://en.wikipedia.org/wiki/Yacc  

Un livre a des contraintes différentes du « monde réel », et donc le style de codage ici peut ne pas toujours refléter la meilleure manière d’écrire un logiciel de production maintenable.  
Si je semble un peu cavalier à propos, par exemple, d’ommettre `private` ou de déclarer une variable globale, comprenez que je le fais pour rendre le code plus lisible pour vous.  
Les pages ici ne sont pas aussi larges que votre IDE et chaque caractère compte.  

De plus, le code ne contient pas beaucoup de commentaires.  
C’est parce que chaque poignée de lignes est entourée de plusieurs paragraphes de prose honnête expliquant son fonctionnement.  
Lorsque vous écrivez un livre pour accompagner votre programme, vous pouvez également omettre les commentaires.  
Sinon, vous devriez probablement utiliser `//` un peu plus que moi.  

Bien que le livre contienne chaque ligne de code et explique ce que chacune signifie, il ne décrit pas la machinerie nécessaire pour compiler et exécuter l’interpréteur.  
Je suppose que vous pouvez créer un makefile ou un projet dans l’IDE de votre choix pour exécuter le code.  
Ce genre d’instructions devient vite obsolète, et je veux que ce livre vieillisse comme un XO, pas comme de l’alcool de contrebande maison.  

### Extraits de code

Puisque le livre contient littéralement chaque ligne de code nécessaire pour les implémentations, les extraits sont assez précis.  
De plus, parce que j’essaie de garder le programme dans un état exécutable même lorsque des fonctionnalités majeures manquent, nous ajoutons parfois du code temporaire qui sera remplacé dans les extraits suivants.  

Un extrait avec toutes les fioritures ressemble à ceci :

<div class="codehilite"><pre class="insert-before">
      default:
</pre><div class="source-file"><em>lox/Scanner.java</em><br>
dans <em>scanToken</em>()<br>
remplacer 1 ligne</div>
<pre class="insert">
        <span class="k">if</span> (<span class="i">isDigit</span>(<span class="i">c</span>)) {
          <span class="i">number</span>();
        } <span class="k">else</span> {
          <span class="t">Lox</span>.<span class="i">error</span>(<span class="i">line</span>, <span class="s">&quot;Unexpected character.&quot;</span>);
        }
</pre><pre class="insert-after">
        break;
</pre></div>
<div class="source-file-narrow"><em>lox/Scanner.java</em>, dans <em>scanToken</em>(), remplacer 1 ligne</div>


Au centre, vous avez le nouveau code à ajouter.  
Il peut y avoir quelques lignes estompées au-dessus ou en dessous pour montrer où il s’insère dans le code existant.  
Il y a aussi un petit encadré indiquant dans quel fichier et où placer l’extrait.  
Si cet encadré dit « remplacer _ ligne », il y a du code existant entre les lignes estompées que vous devez supprimer et remplacer par le nouvel extrait.  

### Asides

<span name="joke">Asides</span> contiennent des profils biographiques, un contexte historique, des références à des sujets connexes et des suggestions d’autres domaines à explorer.  
Il n’y a rien que vous ayez *besoin* de connaître dedans pour comprendre les parties suivantes du livre, donc vous pouvez les ignorer si vous voulez.  
Je ne vous jugerai pas, mais je pourrais être un peu triste.  

<aside name="joke">

Eh bien, certains asides en ont besoin, au moins.  
La plupart d’entre eux sont juste des blagues stupides et des dessins amateurs.  

</aside>


### Défis

Chaque chapitre se termine par quelques exercices. Contrairement aux séries de problèmes des manuels, qui tendent à revoir le matériel que vous avez déjà couvert, ceux-ci sont conçus pour vous aider à apprendre *plus* que ce qui est dans le chapitre.  
Ils vous obligent à sortir du chemin guidé et à explorer par vous-même.  
Ils vous feront rechercher d’autres langages, comprendre comment implémenter des fonctionnalités, ou simplement vous sortir de votre zone de confort.  

<span name="warning">Vainquez</span> les défis et vous repartirez avec une compréhension plus large et peut-être quelques bosses et égratignures.  
Ou sautez-les si vous voulez rester dans le confort du bus touristique. C’est votre livre.  

<aside name="warning">

Un mot d’avertissement : les défis vous demandent souvent d’apporter des modifications à l’interpréteur que vous êtes en train de construire.  
Vous voudrez implémenter ces modifications dans une copie de votre code.  
Les chapitres suivants supposent que votre interpréteur est dans un état impeccable (« non défié » ?).  

</aside>

### Notes de conception

La plupart des livres sur les « langages de programmation » sont strictement des livres sur l’*implémentation* de langages de programmation.  
Ils discutent rarement de la manière dont on pourrait *concevoir* le langage qu’on implémente.  
L’implémentation est amusante parce qu’elle est si <span name="benchmark">précisément définie</span>.  
Nous, programmeurs, semblons avoir une affinité pour les choses en noir et blanc, des uns et des zéros.  

<aside name="benchmark">

Je connais beaucoup de bidouilleurs de langages dont la carrière est basée sur cela.  
Vous glissez une spécification de langage sous leur porte, attendez quelques mois, et le code et les résultats de benchmarks en sortent.  

</aside>

Personnellement, je pense que le monde n’a besoin que d’un nombre limité d’implémentations de <span name="fortran">FORTRAN 77</span>.  
À un moment donné, vous vous retrouvez à concevoir un *nouveau* langage.  
Une fois que vous commencez à jouer à *ce* jeu, alors le côté plus humain et subtil de l’équation devient primordial.  
Des choses comme quelles fonctionnalités sont faciles à apprendre, comment équilibrer innovation et familiarité, quelle syntaxe est plus lisible et pour qui.  

<aside name="fortran">

Espérons que votre nouveau langage ne codifie pas des hypothèses sur la largeur d’une carte perforée dans sa grammaire.  

</aside>

Tout cela affecte profondément le succès de votre nouveau langage.  
Je veux que votre langage réussisse, donc dans certains chapitres, je termine par une « note de conception », un petit essai sur un aspect humain des langages de programmation.  
Je ne suis pas un expert là-dessus — je ne sais pas si quelqu’un l’est vraiment — donc prenez ces notes avec une grande pincée de sel.  
Cela devrait en faire une nourriture plus savoureuse pour la réflexion, ce qui est mon objectif principal.


## Le premier interpréteur

Nous allons écrire notre premier interpréteur, jlox, en <span name="lang">Java</span>.  
L’accent est mis sur les *concepts*. Nous écrirons le code le plus simple et le plus clair possible pour implémenter correctement la sémantique du langage.  
Cela nous permettra de nous familiariser avec les techniques de base et aussi d’affiner notre compréhension de la manière exacte dont le langage est censé se comporter.  

<aside name="lang">

Le livre utilise Java et C, mais des lecteurs ont porté le code vers [beaucoup d’autres langages][port].  
Si les langages que j’ai choisis ne vous conviennent pas, jetez un œil à ceux-là.  

[port]: https://github.com/munificent/craftinginterpreters/wiki/Lox-implementations

</aside>

Java est un excellent langage pour cela.  
Il est suffisamment haut niveau pour que nous ne soyons pas submergés par des détails d’implémentation fastidieux, mais reste assez explicite.  
Contrairement aux langages de script, il y a tendance à avoir moins de machinerie complexe cachée sous le capot, et vous disposez de types statiques pour voir quelles structures de données vous utilisez.  

J’ai également choisi Java spécifiquement parce que c’est un langage orienté objet.  
Ce paradigme a envahi le monde de la programmation dans les années 90 et est maintenant la façon dominante de penser pour des millions de programmeurs.  
Il y a de bonnes chances que vous soyez déjà habitué à organiser le code en classes et méthodes, donc nous resterons dans cette zone de confort.  

Bien que les universitaires spécialisés en langages regardent parfois de haut les langages orientés objet, la réalité est qu’ils sont largement utilisés même pour le travail sur les langages.  
GCC et LLVM sont écrits en C++, tout comme la plupart des machines virtuelles JavaScript.  
Les langages orientés objet sont omniprésents, et les outils et compilateurs *pour* un langage sont souvent écrits *dans* le <span name="host">même langage</span>.  

<aside name="host">

Un compilateur lit des fichiers dans un langage, les traduit et produit des fichiers dans un autre langage.  
Vous pouvez implémenter un compilateur dans n’importe quel langage, y compris le même langage qu’il compile, un processus appelé **self-hosting**.  

Vous ne pouvez pas encore compiler votre compilateur avec lui-même, mais si vous disposez d’un autre compilateur pour votre langage écrit dans un autre langage, vous utilisez *celui-là* pour compiler votre compilateur une fois.  
Maintenant, vous pouvez utiliser la version compilée de votre propre compilateur pour compiler les versions futures de celui-ci, et vous pouvez jeter l’original compilé avec l’autre compilateur.  
Cela s’appelle **bootstrapping**, d’après l’image de se tirer soi-même par ses propres bottes.  

<img src="image/introduction/bootstrap.png" alt="Fait : c’est le principal moyen de transport du cowboy américain." />

</aside>

Enfin, Java est extrêmement populaire.  
Cela signifie qu’il y a de bonnes chances que vous le connaissiez déjà, donc moins de choses à apprendre pour commencer le livre.  
Si vous n’êtes pas très familier avec Java, ne paniquez pas.  
J’essaie de m’en tenir à un sous-ensemble assez minimal.  
J’utilise l’opérateur diamant de Java 7 pour rendre certaines choses un peu plus concises, mais c’est à peu près tout pour les fonctionnalités « avancées ».  
Si vous connaissez un autre langage orienté objet, comme C# ou C++, vous pouvez vous en sortir.  

À la fin de la partie II, nous aurons une implémentation simple et lisible.  
Elle n’est pas très rapide, mais elle est correcte.  
Cependant, nous ne pouvons y parvenir qu’en nous appuyant sur les propres facilités d’exécution de la machine virtuelle Java.  
Nous voulons apprendre comment Java *lui-même* implémente ces choses.


## Le deuxième interpréteur

Dans la partie suivante, nous recommençons depuis le début, mais cette fois en C.  
C est le langage parfait pour comprendre comment une implémentation *fonctionne vraiment*, jusqu’aux octets en mémoire et au code circulant dans le CPU.  

Une grande raison pour laquelle nous utilisons C est que je peux vous montrer des choses dans lesquelles C excelle particulièrement, mais cela signifie que vous devez être assez à l’aise avec ce langage.  
Vous n’avez pas besoin d’être la réincarnation de Dennis Ritchie, mais vous ne devez pas non plus être effrayé par les pointeurs.  

Si vous n’en êtes pas encore là, prenez un livre d’introduction au C et travaillez-le, puis revenez ici une fois terminé.  
En retour, vous sortirez de ce livre un programmeur C encore plus solide.  
C’est utile étant donné le nombre d’implémentations de langages écrites en C : Lua, CPython et MRI de Ruby, pour n’en citer que quelques-unes.  

Dans notre interpréteur C, <span name="clox">clox</span>, nous sommes obligés d’implémenter nous-mêmes toutes les fonctionnalités que Java nous fournissait gratuitement.  
Nous écrirons notre propre tableau dynamique et table de hachage.  
Nous déciderons comment les objets sont représentés en mémoire, et construirons un ramasse-miettes pour les récupérer.  

<aside name="clox">

Je prononce le nom « sea-locks », mais vous pouvez dire « clocks » ou même « cloch », où vous prononcez le « x » à la manière des Grecs si cela vous rend heureux.  

</aside>

Notre implémentation Java se concentrait sur la correction.  
Maintenant que nous avons cela, nous allons également viser la *performance*.  
Notre interpréteur C contiendra un <span name="compiler">compilateur</span> qui traduit Lox en une représentation bytecode efficace (ne vous inquiétez pas, je vais expliquer ce que cela signifie bientôt), qu’il exécute ensuite.  
C’est la même technique utilisée par les implémentations de Lua, Python, Ruby, PHP et beaucoup d’autres langages à succès.  

<aside name="compiler">

Vous pensiez que ce n’était qu’un livre sur les interpréteurs ? C’est aussi un livre sur les compilateurs.  
Deux pour le prix d’un !  

</aside>

Nous essaierons même le benchmarking et l’optimisation.  
À la fin, nous aurons un interpréteur robuste, précis et rapide pour notre langage, capable de rivaliser avec d’autres implémentations professionnelles.  
Pas mal pour un seul livre et quelques milliers de lignes de code.  

<div class="challenges">

## Défis

1.  Il y a au moins six langages spécifiques à un domaine utilisés dans le [petit système que j’ai bricolé][repo] pour écrire et publier ce livre. Quels sont-ils ?  

1.  Écrivez et exécutez un programme « Hello, world! » en Java.  
    Configurez les makefiles ou projets IDE nécessaires pour le faire fonctionner.  
    Si vous avez un débogueur, familiarisez-vous avec et suivez votre programme à l’exécution.  

1.  Faites la même chose pour C.  
    Pour vous entraîner aux pointeurs, définissez une [liste doublement chaînée][] de chaînes allouées sur le tas.  
    Écrivez des fonctions pour insérer, trouver et supprimer des éléments. Testez-les.  

[repo]: https://github.com/munificent/craftinginterpreters  
[doubly linked list]: https://en.wikipedia.org/wiki/Doubly_linked_list  

</div>

<div class="design-note">


## Note de conception : Que contient un nom ?

Un des défis les plus difficiles dans l’écriture de ce livre a été de trouver un nom pour le langage qu’il implémente.  
J’ai parcouru *des pages* de candidats avant d’en trouver un qui fonctionnait.  
Comme vous le découvrirez le premier jour où vous commencerez à construire votre propre langage, trouver un nom est diaboliquement difficile.  
Un bon nom satisfait quelques critères :  

1.  **Il n’est pas déjà utilisé.** Vous pouvez rencontrer toutes sortes de problèmes, légaux et sociaux, si vous empiétez involontairement sur le nom de quelqu’un d’autre.  

2.  **Il est facile à prononcer.** Si tout se passe bien, des hordes de personnes diront et écriront le nom de votre langage. Tout nom de plus de quelques syllabes ou quelques lettres les agacera à outrance.  

3.  **Il est suffisamment distinct pour être recherché.** Les gens Googleront le nom de votre langage pour en savoir plus, donc vous voulez un mot assez rare pour que la plupart des résultats pointent vers votre documentation.  
    Bien que, avec le volume actuel des moteurs de recherche IA, ce n’est plus vraiment un problème.  
    Cependant, vous ne rendrez pas service à vos utilisateurs si vous nommez votre langage « for ».  

4.  **Il n’a pas de connotations négatives dans plusieurs cultures.** C’est difficile d’être vigilant à ce sujet, mais cela vaut la peine d’y penser.  
    Le concepteur de Nimrod a fini par renommer son langage « Nim » parce que trop de gens se souvenaient que Bugs Bunny utilisait « Nimrod » comme une insulte. (Bugs l’utilisait ironiquement.)  

Si votre nom potentiel passe ce parcours du combattant, conservez-le.  
Ne vous bloquez pas à essayer de trouver un nom qui capture la quintessence de votre langage.  
Si les noms des autres langages à succès dans le monde nous enseignent quelque chose, c’est que le nom n’a pas beaucoup d’importance.  
Tout ce dont vous avez besoin est un token raisonnablement unique.