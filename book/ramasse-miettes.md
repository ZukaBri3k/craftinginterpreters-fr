> I wanna, I wanna,<br />
> I wanna, I wanna,<br />
> I wanna be trash.<br />
>
> <cite>The Whip, &ldquo;Trash&rdquo;</cite>

Nous disons que Lox est un langage de "haut niveau" parce qu'il libère les programmeurs de s'inquiéter des détails non pertinents au problème qu'ils résolvent. L'utilisateur devient un exécutif, donnant à la machine des buts abstraits et laissant l'humble ordinateur trouver comment y arriver.

L'allocation dynamique de mémoire est un candidat parfait pour l'automatisation. C'est nécessaire pour un programme fonctionnel, fastidieux à faire à la main, et pourtant encore sujet aux erreurs. Les erreurs inévitables peuvent être catastrophiques, menant à des plantages, de la corruption de mémoire, ou des violations de sécurité. C'est le genre de travail risqué-mais-ennuyeux auquel les machines excellent par rapport aux humains.

C'est pourquoi Lox est un **langage géré**, ce qui signifie que l'implémentation du langage gère l'allocation mémoire et la libération au nom de l'utilisateur. Quand un utilisateur effectue une opération qui requiert un peu de mémoire dynamique, la VM l'alloue automatiquement. Le programmeur ne s'inquiète jamais de désallouer quoi que ce soit. La machine assure que toute mémoire que le programme utilise reste dans les parages aussi longtemps que nécessaire.

Lox fournit l'illusion que l'ordinateur a une quantité infinie de mémoire. Les utilisateurs peuvent allouer et allouer et allouer et ne jamais une fois penser à d'où tous ces octets viennent. Bien sûr, les ordinateurs n'_ont_ pas encore de mémoire infinie. Donc la façon dont les langages gérés maintiennent cette illusion est en allant dans le dos du programmeur et en réclamant la mémoire dont le programme n'a plus besoin. Le composant qui fait cela est appelé un **ramasse-miettes** (garbage <span name="recycle">collector</span>).

<aside name="recycle">

Recyclage serait vraiment une meilleure métaphore pour cela. Le GC ne _jette pas_ la mémoire, il la réclame pour être réutilisée pour de nouvelles données. Mais les langages gérés sont plus vieux que le Jour de la Terre, donc les inventeurs sont allés avec l'analogie qu'ils connaissaient.

<img src="image/garbage-collection/recycle.png" class="above" alt="Une poubelle de recyclage pleine de bits." />

</aside>

## Accessibilité

Cela soulève une question étonnamment difficile : comment une VM dit-elle quelle mémoire n'est _pas_ nécessaire ? La mémoire est seulement nécessaire si elle est lue dans le futur, mais à moins d'avoir une machine à voyager dans le temps, comment une implémentation peut-elle dire quel code le programme _exécutera_ et quelles données il _utilisera_ ? Spoiler alert : les VMs ne peuvent pas voyager dans le futur. Au lieu de cela, le langage fait une approximation <span name="conservative">conservatrice</span> : il considère un morceau de mémoire comme étant encore utilisé s'il _pourrait possiblement_ être lu dans le futur.

<aside name="conservative">

J'utilise "conservateur" dans le sens général. Il y a une chose telle qu'un "ramasse-miettes conservateur" ce qui signifie quelque chose de plus spécifique. Tous les ramasse-miettes sont "conservateurs" en ce qu'ils gardent la mémoire vivante si elle _pourrait_ être accédée, au lieu d'avoir une boule magique numéro 8 qui leur laisse savoir plus précisément quelles données _seront_ accédées.

Un **GC conservateur** est une sorte spéciale de collecteur qui considère n'importe quel morceau de mémoire comme un pointeur si la valeur dedans ressemble à ce qu'elle pourrait être une adresse. C'est en contraste avec un **GC précis** -- qui est ce que nous implémenterons -- qui sait exactement quels mots en mémoire sont des pointeurs et lesquels stockent d'autres sortes de valeurs comme des nombres ou des chaînes.

</aside>

Cela semble _trop_ conservateur. _N'importe quel_ bout de mémoire ne pourrait-il pas potentiellement être lu ? En fait, non, au moins pas dans un langage sûr en mémoire comme Lox. Voici un exemple :

```lox
var a = "first value";
a = "updated";
// GC here.
print a;
```

Disons que nous courons le GC après que l'assignation a complété sur la seconde ligne. La chaîne "first value" est encore assise en mémoire, mais il n'y a aucun moyen pour le programme de l'utilisateur d'arriver à elle. Une fois que `a` a été réassigné, le programme a perdu toute référence à cette chaîne. Nous pouvons la libérer sûrement. Une valeur est **accessible** (reachable) s'il y a quelque moyen pour un programme utilisateur de la référencer. Sinon, comme la chaîne "first value" ici, elle est **inaccessible** (unreachable).

Beaucoup de valeurs peuvent être directement accédées par la VM. Jetez un coup d'œil à :

```lox
var global = "string";
{
  var local = "another";
  print global + local;
}
```

Mettez le programme en pause juste après que les deux chaînes ont été concaténées mais avant que l'instruction `print` ait exécuté. La VM peut atteindre `"string"` en regardant à travers la table des variables globales et en trouvant l'entrée pour `global`. Elle peut trouver `"another"` en marchant la pile de valeurs et en frappant l'emplacement pour la variable locale `local`. Elle peut même trouver la chaîne concaténée `"stringanother"` puisque cette valeur temporaire est aussi assise sur la pile de la VM au point où nous avons pausé notre programme.

Toutes ces valeurs sont appelées des **racines**. Une racine est n'importe quel objet que la VM peut atteindre directement sans passer par une référence dans quelque autre objet. La plupart des racines sont des variables globales ou sur la pile, mais comme nous verrons, il y a une paire d'autres endroits où la VM stocke des références aux objets qu'elle peut trouver.

D'autres valeurs peuvent être trouvées en passant par une référence à l'intérieur d'une autre valeur. Les <span name="class">champs</span> sur les instances de classes sont le cas le plus évident, mais nous n'avons pas ceux-là encore. Même sans ceux-là, notre VM a encore des références indirectes. Considérez :

<aside name="class">

Nous y arriverons [bientôt][classes], cependant !

[classes]: classes-et-instances.html

</aside>

```lox
fun makeClosure() {
  var a = "data";

  fun f() { print a; }
  return f;
}

{
  var closure = makeClosure();
  // GC here.
  closure();
}
```

Disons que nous mettons en pause le programme sur la ligne marquée et courons le ramasse-miettes. Quand le collecteur a fini et que le programme reprend, il appellera la fermeture, qui appellera à son tour l'affichage de `"data"`. Donc le collecteur a besoin de _ne pas_ libérer cette chaîne. Mais voici à quoi la pile ressemble quand nous mettons en pause le programme :

<img src="image/garbage-collection/stack.png" alt="La pile, contenant seulement le script et la fermeture." />

La chaîne `"data"` n'est nulle part dessus. Elle a déjà été hissée hors de la pile et déplacée dans l'upvalue fermée que la fermeture utilise. La fermeture elle-même est sur la pile. Mais pour arriver à la chaîne, nous avons besoin de tracer à travers la fermeture et son tableau d'upvalues. Puisqu'il _est_ possible pour le programme de l'utilisateur de faire cela, tous ces objets indirectement accessibles sont aussi considérés accessibles.

<img src="image/garbage-collection/reachable.png" class="wide" alt="Tous les objets référencés depuis la fermeture, et le chemin vers la chaîne 'data' depuis la pile." />

Cela nous donne une définition inductive de l'accessibilité :

- Toutes les racines sont accessibles.

- N'importe quel objet référé depuis un objet accessible est lui-même accessible.

Ce sont les valeurs qui sont encore "vivantes" et ont besoin de rester en mémoire. Toute valeur qui ne _rencontre pas_ cette définition est juste gibier pour le collecteur à moissonner. Cette paire récursive de règles laisse entendre un algorithme récursif que nous pouvons utiliser pour libérer la mémoire non nécessaire :

1.  Commençant avec les racines, traverser à travers les références d'objet pour trouver l'ensemble complet des objets accessibles.

2.  Libérer tous les objets _pas_ dans cet ensemble.

Beaucoup d'algorithmes de ramasse-miettes <span name="handbook">différents</span> sont en usage aujourd'hui, mais ils suivent tous grossièrement cette même structure. Certains peuvent entremêler les étapes ou les mélanger, mais les deux opérations fondamentales sont là. Ils diffèrent surtout dans _comment_ ils effectuent chaque étape.

<aside name="handbook">

Si vous voulez explorer d'autres algorithmes de GC,
[_The Garbage Collection Handbook_][gc book] (Jones, et al.) est la référence canonique. Pour un gros livre sur un tel sujet profond, étroit, il est assez agréable à lire. Ou peut-être j'ai une idée étrange du fun.

[gc book]: http://gchandbook.org/

</aside>

## Ramasse-miettes Mark-Sweep

Le premier langage géré fut Lisp, le second langage de "haut niveau" à être inventé, juste après Fortran. John McCarthy considéra utiliser la gestion manuelle de mémoire ou le comptage de références, mais s'installa <span name="procrastination">éventuellement</span> sur (et inventa le terme) ramasse-miettes -- une fois que le programme était à court de mémoire, il retournerait en arrière et trouverait le stockage inutilisé qu'il pourrait réclamer.

<aside name="procrastination">

Dans "History of Lisp" de John McCarthy, il note : "Une fois que nous avons décidé sur le ramasse-miettes, son implémentation actuelle pouvait être reportée, parce que seulement des exemples jouets étaient faits." Notre choix de procrastiner l'ajout du GC à clox suit dans les pas des géants.

</aside>

Il a conçu le tout premier, plus simple algorithme de ramasse-miettes, appelé **mark-and-sweep** (marquer-et-balayer) ou juste **mark-sweep**. Sa description tient dans trois courts paragraphes dans le papier initial sur Lisp. Malgré son âge et sa simplicité, le même algorithme fondamental sous-tend beaucoup de gestionnaires de mémoire modernes. Certains coins de l'informatique semblent être intemporels.

Comme le nom l'implique, le mark-sweep fonctionne en deux phases :

- **Marquage (Marking) :** Nous commençons avec les racines et traversons ou <span name="trace">_traçons_</span> à travers tous les objets auxquels ces racines se réfèrent. C'est une traversée de graphe classique de tous les objets accessibles. Chaque fois que nous visitons un objet, nous le _marquons_ de quelque manière. (Les implémentations diffèrent dans comment elles enregistrent la marque.)

- **Balayage (Sweeping) :** Une fois que la phase de marquage complète, chaque objet accessible dans le tas a été marqué. Cela signifie que tout objet non marqué est inaccessible et mûr pour la réclamation. Nous passons à travers tous les objets non marqués et libérons chacun d'eux.

Cela ressemble à quelque chose comme ceci :

<img src="image/garbage-collection/mark-sweep.png" class="wide" alt="Commençant depuis un graphe d'objets, d'abord les accessibles sont marqués, les restants sont balayés, et ensuite seulement les accessibles restent." />

<aside name="trace">

Un **ramasse-miettes traceur** est n'importe quel algorithme qui trace à travers le graphe des références d'objet. C'est en contraste avec le comptage de références, qui a une stratégie différente pour suivre les objets accessibles.

</aside>

C'est ce que nous allons implémenter. Chaque fois que nous décidons qu'il est temps de réclamer quelques octets, nous tracerons tout et marquerons tous les objets accessibles, libérerons ce qui n'a pas été marqué, et ensuite reprendrons le programme de l'utilisateur.

### Collecter les miettes

Ce chapitre entier est à propos d'implémenter cette <span name="one">fonction</span> unique :

<aside name="one">

Bien sûr, nous finirons par ajouter un tas de fonctions d'aide aussi.

</aside>

^code collect-garbage-h (1 before, 1 after)

Nous travaillerons notre chemin vers une implémentation complète commençant avec cette coque vide :

^code collect-garbage

La première question que vous pourriez demander est, Quand cette fonction est-elle appelée ? Il s'avère que c'est une question subtile sur laquelle nous passerons un peu de temps plus tard dans le chapitre. Pour le moment nous esquiverons le problème et nous construirons un outil de diagnostic pratique dans le processus.

^code define-stress-gc (1 before, 2 after)

Nous ajouterons un mode optionnel "stress test" pour le ramasse-miettes. Quand ce drapeau est défini, le GC court aussi souvent qu'il peut possiblement. C'est, évidemment, horrifique pour la performance. Mais c'est génial pour débusquer les bugs de gestion de mémoire qui se produisent seulement quand un GC est déclenché juste au bon moment. Si _chaque_ moment déclenche un GC, vous êtes susceptibles de trouver ces bugs.

^code call-collect (1 before, 1 after)

Chaque fois que nous appelons `reallocate()` pour acquérir plus de mémoire, nous forçons une collection à courir. La vérification if est parce que `reallocate()` est aussi appelé pour libérer ou rétrécir une allocation. Nous ne voulons pas déclencher un GC pour cela -- en particulier parce que le GC lui-même appellera `reallocate()` pour libérer de la mémoire.

Collecter juste avant l'<span name="demand">allocation</span> est la façon classique de câbler un GC dans une VM. Vous appelez déjà dans le gestionnaire de mémoire, donc c'est un endroit facile pour accrocher le code. Aussi, l'allocation est le seul moment où vous avez vraiment _besoin_ de mémoire libérée pour que vous puissiez la réutiliser. Si vous n'utilisez _pas_ l'allocation pour déclencher un GC, vous devez vous assurer que chaque endroit possible dans le code où vous pouvez boucler et allouer de la mémoire a aussi un moyen de déclencher le collecteur. Sinon, la VM peut entrer dans un état affamé où elle a besoin de plus de mémoire mais n'en collecte jamais.

<aside name="demand">

Des collecteurs plus sophistiqués pourraient courir sur un fil séparé ou être entrelacés périodiquement durant l'exécution du programme -- souvent aux frontières d'appel de fonction ou quand un saut en arrière se produit.

</aside>

### Journalisation de débogage

Pendant que nous sommes sur le sujet des diagnostics, mettons-en un peu plus. Un vrai défi que j'ai trouvé avec les ramasse-miettes est qu'ils sont opaques. Nous avons couru des tas de programmes Lox juste bien sans aucun GC _du tout_ jusqu'ici. Une fois que nous en ajoutons un, comment disons-nous s'il fait quoi que ce soit d'utile ? Pouvons-nous dire seulement si nous écrivons des programmes qui labourent à travers des acres de mémoire ? Comment déboguons-nous cela ?

Un moyen facile de briller une lumière dans les fonctionnements internes du GC est avec un peu de journalisation.

^code define-log-gc (1 before, 2 after)

Quand c'est activé, clox affiche de l'information sur la console quand il fait quelque chose avec la mémoire dynamique.

Nous avons besoin d'une paire d'includes.

^code debug-log-includes (1 before, 2 after)

Nous n'avons pas de collecteur encore, mais nous pouvons commencer à mettre dedans certaines des journalisations maintenant. Nous voudrons savoir quand une course de collection démarre.

^code log-before-collect (1 before, 1 after)

Éventuellement nous journaliserons quelques autres opérations durant la collection, donc nous voudrons aussi savoir quand le spectacle est fini.

^code log-after-collect (2 before, 1 after)

Nous n'avons aucun code pour le collecteur encore, mais nous avons bien des fonctions pour allouer et libérer, donc nous pouvons instrumenter celles-là maintenant.

^code debug-log-allocate (1 before, 1 after)

Et à la fin de la durée de vie d'un objet :

^code log-free-object (1 before, 1 after)

Avec ces deux drapeaux, nous devrions être capables de voir que nous faisons des progrès comme nous travaillons à travers le reste du chapitre.

## Marquer les Racines

Les objets sont dispersés à travers le tas comme des étoiles dans le ciel nocturne d'encre. Une référence d'un objet à un autre forme une connexion, et ces constellations sont le graphe que la phase de marquage traverse. Le marquage commence aux racines.

^code call-mark-roots (3 before, 2 after)

La plupart des racines sont des variables locales ou temporaires assises juste dans la pile de la VM, donc nous commençons par marcher celle-là.

^code mark-roots

Pour marquer une valeur Lox, nous utilisons cette nouvelle fonction :

^code mark-value-h (1 before, 1 after)

Son implémentation est ici :

^code mark-value

Certaines valeurs Lox -- nombres, Booléens, et `nil` -- sont stockées directement en ligne dans Value et ne requièrent aucune allocation tas. Le ramasse-miettes n'a pas besoin de s'inquiéter à propos d'elles du tout, donc la première chose que nous faisons est d'assurer que la valeur est un objet tas réel. Si oui, le vrai travail se passe dans cette fonction :

^code mark-object-h (1 before, 1 after)

Qui est définie ici :

^code mark-object

La vérification `NULL` est inutile quand appelée depuis `markValue()`. Une Value Lox qui est quelque sorte de type Obj aura toujours un pointeur valide. Mais plus tard nous appellerons cette fonction directement depuis d'autres codes, et dans certains de ces endroits, l'objet étant pointé est optionnel.

Supposant que nous avons bien un objet valide, nous le marquons en mettant un drapeau. Ce nouveau champ vit dans la structure d'en-tête Obj que tous les objets partagent.

^code is-marked-field (1 before, 1 after)

Chaque nouvel objet commence sa vie non marqué parce que nous n'avons pas encore déterminé s'il est accessible ou non.

^code init-is-marked (1 before, 2 after)

Avant que nous allions plus loin, ajoutons un peu de journalisation à `markObject()`.

^code log-mark-object (2 before, 1 after)

De cette façon nous pouvons voir ce que la phase de marquage fait. Marquer la pile s'occupe des variables locales et temporaires. L'autre source principale de racines sont les variables globales.

^code mark-globals (2 before, 1 after)

Celles-là vivent dans une table de hachage possédée par la VM, donc nous déclarerons une autre fonction d'aide pour marquer tous les objets dans une table.

^code mark-table-h (2 before, 2 after)

Nous implémentons cela dans le module "table" ici :

^code mark-table

Assez direct. Nous marchons le tableau d'entrées. Pour chacune, nous marquons sa valeur. Nous marquons aussi les chaînes clés pour chaque entrée puisque le GC gère ces chaînes aussi.

### Racines moins évidentes

Celles-là couvrent les racines auxquelles nous pensons typiquement -- les valeurs qui sont évidemment accessibles parce qu'elles sont stockées dans des variables que le programme de l'utilisateur peut voir. Mais la VM a quelques-uns de ses propres trous de cachette où elle écureuille des références à des valeurs qu'elle accède directement.

La plupart de l'état d'appel de fonction vit dans la pile de valeurs, mais la VM maintient une pile séparée de CallFrames. Chaque CallFrame contient un pointeur vers la fermeture étant appelée. La VM utilise ces pointeurs pour accéder aux constantes et upvalues, donc ces fermetures ont besoin d'être gardées autour aussi.

^code mark-closures (1 before, 2 after)

Parlant d'upvalues, la liste d'upvalues ouvertes est un autre ensemble de valeurs que la VM peut atteindre directement.

^code mark-open-upvalues (3 before, 2 after)

Rappelez-vous aussi qu'une collection peut commencer durant _n'importe quelle_ allocation. Ces allocations n'arrivent pas juste pendant que le programme de l'utilisateur court. Le compilateur lui-même attrape périodiquement de la mémoire depuis le tas pour les littéraux et la table des constantes. Si le GC court pendant que nous sommes au milieu de la compilation, alors toutes valeurs que le compilateur accède directement ont besoin d'être traitées comme des racines aussi.

Pour garder le module compilateur proprement séparé du reste de la VM, nous ferons cela dans une fonction séparée.

^code call-mark-compiler-roots (1 before, 1 after)

C'est déclaré ici :

^code mark-compiler-roots-h (1 before, 2 after)

Ce qui signifie que le module "memory" a besoin d'un include.

^code memory-include-compiler (2 before, 1 after)

Et la définition est là-bas dans le module "compiler".

^code mark-compiler-roots

Heureusement, le compilateur n'a pas trop de valeurs auxquelles il s'accroche. Le seul objet qu'il utilise est l'ObjFunction dans lequel il compile. Puisque les déclarations de fonction peuvent s'imbriquer, le compilateur a une liste chaînée de celles-ci et nous marchons la liste entière.

Puisque le module "compiler" appelle `markObject()`, il a aussi besoin d'un include.

^code compiler-include-memory (1 before, 1 after)

Ce sont toutes les racines. Après avoir couru cela, chaque objet que la VM -- runtime et compilateur -- peut atteindre _sans_ passer par quelque autre objet a son bit de marque mis.
## Tracer les Références d'Objet

L'étape suivante dans le processus de marquage est de tracer à travers le graphe des références entre les objets pour trouver les valeurs indirectement accessibles. Nous n'avons pas d'instances avec des champs encore, donc il n'y a pas beaucoup d'objets qui contiennent des références, mais nous en avons <span name="some">quelques-uns</span>. En particulier, ObjClosure a la liste des ObjUpvalues sur lesquels il ferme ainsi qu'une référence à l'ObjFunction brut qu'il enveloppe. ObjFunction, à son tour, a une table constante empaquetée pleine de références vers tous les littéraux créés dans le corps de la fonction. C'est assez pour construire une toile d'objets assez complexe pour le collecteur à travers laquelle ramper.

<aside name="some">

J'ai inséré ce chapitre dans le livre juste ici spécifiquement _parce que_ nous avons maintenant des fermetures qui nous donnent des objets intéressants pour le ramasse-miettes à traiter.

</aside>

Maintenant il est temps d'implémenter cette traversée. Nous pouvons aller en largeur d'abord, en profondeur d'abord, ou dans quelque autre ordre. Puisque nous avons juste besoin de trouver l'_ensemble_ de tous les objets accessibles, l'ordre dans lequel nous les visitons <span name="dfs">surtout</span> n'importe pas.

<aside name="dfs">

Je dis "surtout" parce que certains ramasse-miettes déplacent les objets dans l'ordre où ils sont visités, donc l'ordre de traversée détermine quels objets finissent adjacents en mémoire. Cela impacte la performance parce que le CPU utilise la localité pour déterminer quelle mémoire précharger dans les caches.

Même quand l'ordre de traversée importe, il n'est pas clair quel ordre est le _meilleur_. Il est très difficile de déterminer dans quel ordre les objets seront utilisés dans le futur, donc il est dur pour le GC de savoir quel ordre aidera la performance.

</aside>

### L'abstraction tricolore

Comme le collecteur erre à travers le graphe d'objets, nous avons besoin de nous assurer qu'il ne perd pas la trace de où il est ou ne reste pas coincé à aller en cercles. C'est particulièrement une préoccupation pour les implémentations avancées comme les GCs incrémentaux qui entremêlent le marquage avec l'exécution de morceaux du programme de l'utilisateur. Le collecteur a besoin d'être capable de mettre en pause et ensuite reprendre où il s'est arrêté plus tard.

Pour nous aider humains au cerveau mou à raisonner sur ce processus complexe, les hackers de VM sont venus avec une métaphore appelée l'<span name="color"></span>**abstraction tricolore** (tricolor abstraction). Chaque objet a une "couleur" conceptuelle qui suit dans quel état l'objet est, et quel travail est laissé à faire.

<aside name="color">

Les algorithmes de ramasse-miettes avancés ajoutent souvent d'autres couleurs à l'abstraction. J'ai vu de multiples nuances de gris, et même pourpre dans certaines conceptions. Mon papier de collecteur puce-chartreuse-fuchsia-malachite n'a, hélas, pas été accepté pour publication.

</aside>

- **<img src="image/garbage-collection/white.png" alt="Un cercle blanc." class="dot" /> Blanc :** Au début d'un ramasse-miettes, chaque objet est blanc. Cette couleur signifie que nous n'avons pas atteint ou traité l'objet du tout.

- **<img src="image/garbage-collection/gray.png" alt="Un cercle gris." class="dot" /> Gris :** Durant le marquage, quand nous atteignons d'abord un objet, nous l'assombrissons en gris. Cette couleur signifie que nous savons que l'objet lui-même est accessible et ne devrait pas être collecté. Mais nous n'avons pas encore tracé _à travers_ lui pour voir quels _autres_ objets il référence. En termes d'algorithme de graphe, c'est la _worklist_ (liste de travail) -- l'ensemble des objets que nous connaissons mais n'avons pas traités encore.

- **<img src="image/garbage-collection/black.png" alt="Un cercle noir." class="dot" /> Noir :** Quand nous prenons un objet gris et marquons tous les objets qu'il référence, nous tournons alors l'objet gris en noir. Cette couleur signifie que la phase de marquage a fini de traiter cet objet.

En termes de cette abstraction, le processus de marquage ressemble maintenant à ceci :

1.  Démarrer avec tous les objets blancs.

2.  Trouver toutes les racines et les marquer grises.

3.  Répéter tant qu'il y a encore des objets gris :
    1.  Prendre un objet gris. Tourner tous objets blancs que l'objet mentionne en gris.

    2.  Marquer l'objet gris original en noir.

Je trouve que cela aide de visualiser ceci. Vous avez une toile d'objets avec des références entre eux. Initialement, ils sont tous de petits points blancs. Sur le côté sont quelques arêtes entrantes depuis la VM qui pointent vers les racines. Ces racines tournent gris. Ensuite les frères et sœurs de chaque objet gris tournent gris tandis que l'objet lui-même tourne noir. L'effet complet est un front d'onde gris qui passe à travers le graphe, laissant un champ d'objets noirs accessibles derrière lui. Les objets inaccessibles ne sont pas touchés par le front d'onde et restent blancs.

<img src="image/garbage-collection/tricolor-trace.png" class="wide" alt="Un front d'onde gris travaillant à travers un graphe de nœuds." />

À la <span name="invariant">fin</span>, vous êtes laissés avec une mer d'objets noirs, atteints saupoudrée avec des îles d'objets blancs qui peuvent être balayés et libérés. Une fois que les objets inaccessibles sont libérés, les objets restants -- tous noirs -- sont remis à zéro à blanc pour le prochain cycle de ramasse-miettes.

<aside name="invariant">

Notez qu'à chaque étape de ce processus aucun nœud noir ne pointe jamais vers un nœud blanc. Cette propriété est appelée l'**invariant tricolore**. Le processus de traversée maintient cet invariant pour assurer qu'aucun objet accessible n'est jamais collecté.

</aside>

### Une liste de travail pour les objets gris

Dans notre implémentation nous avons déjà marqué les racines. Elles sont toutes grises. L'étape suivante est de commencer à les prendre et traverser leurs références. Mais nous n'avons aucun moyen facile de les trouver. Nous mettons un champ sur l'objet, mais c'est tout. Nous ne voulons pas avoir à traverser la liste d'objets entière cherchant des objets avec ce champ mis.

Au lieu de cela, nous créerons une liste de travail séparée pour garder trace de tous les objets gris. Quand un objet tourne gris, en plus de mettre le champ de marque nous l'ajouterons aussi à la liste de travail.

^code add-to-gray-stack (1 before, 1 after)

Nous pourrions utiliser n'importe quelle sorte de structure de données qui nous laisse mettre des éléments dedans et les sortir facilement. J'ai pris une pile parce que c'est le plus simple à implémenter avec un tableau dynamique en C. Cela fonctionne surtout comme d'autres tableaux dynamiques que nous avons construits dans Lox, _sauf_, notez qu'il appelle la fonction `realloc()` du _système_ et pas notre propre enveloppe `reallocate()`. La mémoire pour la pile grise elle-même n'est _pas_ gérée par le ramasse-miettes. Nous ne voulons pas que faire grandir la pile grise durant un GC cause le GC à démarrer récursivement un nouveau GC. Cela pourrait déchirer un trou dans le continuum espace-temps.

Nous gérerons sa mémoire nous-mêmes, explicitement. La VM possède la pile grise.

^code vm-gray-stack (1 before, 1 after)

Elle commence vide.

^code init-gray-stack (1 before, 2 after)

Et nous avons besoin de la libérer quand la VM s'arrête.

^code free-gray-stack (2 before, 1 after)

<span name="robust">Nous</span> prenons pleine responsabilité pour ce tableau. Cela inclut l'échec d'allocation. Si nous ne pouvons pas créer ou faire grandir la pile grise, alors nous ne pouvons pas finir le ramasse-miettes. C'est de mauvaises nouvelles pour la VM, mais heureusement rare puisque la pile grise tend à être assez petite. Ce serait bien de faire quelque chose de plus gracieux, mais pour garder le code dans ce livre simple, nous avortons juste.

<aside name="robust">

Pour être plus robuste, nous pouvons allouer un bloc de mémoire "fonds pour les mauvais jours" quand nous démarrons la VM. Si l'allocation de la pile grise échoue, nous libérons le bloc mauvais jours et essayons encore. Cela peut nous donner assez de marge de manœuvre sur le tas pour créer la pile grise, finir le GC, et libérer plus de mémoire.

</aside>

^code exit-gray-stack (2 before, 1 after)

### Traiter les objets gris

OK, maintenant quand nous avons fini de marquer les racines, nous avons à la fois mis un tas de champs et rempli notre liste de travail avec des objets à mâcher. C'est le moment pour la phase suivante.

^code call-trace-references (1 before, 2 after)

Voici l'implémentation :

^code trace-references

C'est aussi proche de cet algorithme textuel que vous pouvez obtenir. Jusqu'à ce que la pile se vide, nous continuons de tirer des objets gris, traversant leurs références, et ensuite les marquant noirs. Traverser les références d'un objet peut faire apparaître de nouveaux objets blancs qui deviennent marqués gris et ajoutés à la pile. Donc cette fonction oscille en avant et en arrière entre tourner les objets blancs gris et les objets gris noirs, avançant graduellement le front d'onde entier vers l'avant.

C'est ici que nous traversons les références d'un objet unique :

^code blacken-object

Chaque <span name="leaf">sorte</span> d'objet a différents champs qui pourraient référencer d'autres objets, donc nous avons besoin d'un bloc de code spécifique pour chaque type. Nous commençons avec les faciles -- chaînes et objets de fonction native ne contiennent aucune référence sortante donc il n'y a rien à traverser.

<aside name="leaf">

Une optimisation facile que nous pourrions faire dans `markObject()` est de sauter l'ajout de chaînes et fonctions natives à la pile grise du tout puisque nous savons qu'elles n'ont pas besoin d'être traitées. Au lieu de cela, elles pourraient s'assombrir de blanc directement à noir.

</aside>

Notez que nous ne mettons aucun état dans l'objet traversé lui-même. Il n'y a pas d'encodage direct de "noir" dans l'état de l'objet. Un objet noir est n'importe quel objet dont le champ `isMarked` est <span name="field">mis</span> et qui n'est plus dans la pile grise.

<aside name="field">

Vous pouvez justement vous demander pourquoi nous avons le champ `isMarked` du tout. Tout en bon temps, ami.

</aside>

Maintenant commençons à ajouter dedans les autres types d'objet. Le plus simple est les upvalues.

^code blacken-upvalue (2 before, 1 after)

Quand une upvalue est fermée, elle contient une référence à la valeur fermée. Puisque la valeur n'est plus sur la pile, nous avons besoin de nous assurer que nous traçons la référence à elle depuis l'upvalue.

Ensuite sont les fonctions.

^code blacken-function (1 before, 1 after)

Chaque fonction a une référence à un ObjString contenant le nom de la fonction. Plus important, la fonction a une table constante empaquetée pleine de références à d'autres objets. Nous traçons tous ceux-là en utilisant cet assistant :

^code mark-array

Le dernier type d'objet que nous avons maintenant -- nous en ajouterons plus dans les chapitres suivants -- est les fermetures.

^code blacken-closure (1 before, 1 after)

Chaque fermeture a une référence à la fonction nue qu'elle enveloppe, aussi bien qu'un tableau de pointeurs vers les upvalues qu'elle capture. Nous traçons tous ceux-là.

C'est le mécanisme de base pour traiter un objet gris, mais il y a deux bouts lâches à attacher. D'abord, un peu de journalisation.

^code log-blacken-object (1 before, 1 after)

De cette façon, nous pouvons regarder le traçage percoler à travers le graphe d'objets. Parlant de quoi, notez que j'ai dit _graphe_. Les références entre objets sont dirigées, mais cela ne signifie pas qu'elles sont _acycliques !_ Il est entièrement possible d'avoir des cycles d'objets. Quand cela arrive, nous avons besoin d'assurer que notre collecteur ne reste pas coincé dans une boucle infinie comme il ré-ajoute continuellement la même série d'objets à la pile grise.

La correction est facile.

^code check-is-marked (1 before, 1 after)

Si l'objet est déjà marqué, nous ne le marquons pas encore et ainsi ne l'ajoutons pas à la pile grise. Cela assure qu'un objet déjà gris n'est pas ajouté de façon redondante et qu'un objet noir n'est pas tourné par inadvertance de retour à gris. En d'autres termes, cela garde le front d'onde en mouvement vers l'avant à travers seulement les objets blancs.

## Balayer les Objets Inutilisés

Quand la boucle dans `traceReferences()` sort, nous avons traité tous les objets sur lesquels nous pouvions mettre nos mains. La pile grise est vide, et chaque objet dans le tas est soit noir soit blanc. Les objets noirs sont accessibles, et nous voulons nous accrocher à eux. Tout ce qui est encore blanc n'a jamais été touché par la trace et est ainsi déchet. Tout ce qui reste est de les réclamer.

^code call-sweep (1 before, 2 after)

Toute la logique vit dans une fonction.

^code sweep

Je sais que c'est en quelque sorte beaucoup de code et de manigances de pointeur, mais il n'y a pas grand-chose dedans une fois que vous travaillez à travers. La boucle extérieure `while` marche la liste chaînée de chaque objet dans le tas, vérifiant leurs bits de marque. Si un objet est marqué (noir), nous le laissons seul et continuons passé lui. S'il est non marqué (blanc), nous le délions de la liste et le libérons en utilisant la fonction `freeObject()` que nous avons déjà écrite.

<img src="image/garbage-collection/unlink.png" alt="Une poubelle de recyclage pleine de bits." />

La plupart de l'autre code ici s'occupe du fait que retirer un nœud d'une liste unilatéralement chaînée est encombrant. Nous devons continuellement nous souvenir du nœud précédent pour que nous puissions délier son pointeur suivant, et nous devons gérer le cas limite où nous libérons le premier nœud. Mais, sinon, c'est assez simple -- supprimer chaque nœud dans une liste chaînée qui n'a pas un bit mis dedans.

Il y a un petit ajout :

^code unmark (1 before, 1 after)

Après que `sweep()` complète, les seuls objets restants sont les noirs vivants avec leurs bits de marque mis. C'est correct, mais quand le _prochain_ cycle de collection démarre, nous avons besoin que chaque objet soit blanc. Donc chaque fois que nous atteignons un objet noir, nous allons de l'avant et effaçons le bit maintenant en anticipation de la prochaine course.

### Références faibles et la piscine de chaînes

Nous avons presque fini de collecter. Il reste un coin restant de la VM qui a quelques exigences inhabituelles autour de la mémoire. Rappelez-vous que quand nous avons ajouté les chaînes à clox nous avons fait que la VM les interne toutes. Cela signifie que la VM a une table de hachage contenant un pointeur vers chaque chaîne unique dans le tas. La VM utilise cela pour dé-dupliquer les chaînes.

Durant la phase de marquage, nous n'avons délibérément _pas_ traité la table de chaînes de la VM comme une source de racines. Si nous avions, aucune <span name="intern">chaîne</span> ne serait _jamais_ collectée. La table de chaînes grandirait et grandirait et ne céderait jamais un seul octet de mémoire de retour au système d'exploitation. Cela serait mauvais.

<aside name="intern">

Cela peut être un vrai problème. Java n'interne pas _toutes_ les chaînes, mais il interne bien les _littéraux_ chaîne. Il fournit aussi une API pour ajouter des chaînes à la table de chaînes. Pendant de nombreuses années, la capacité de cette table était fixe, et les chaînes ajoutées à elle ne pouvaient jamais être retirées. Si les utilisateurs n'étaient pas prudents sur leur utilisation de `String.intern()`, ils pouvaient tomber à court de mémoire et planter.

Ruby a eu un problème similaire pendant des années où les symboles -- valeurs comme des chaînes internées -- n'étaient pas ramassés. Les deux ont éventuellement activé le GC pour collecter ces chaînes.

</aside>

En même temps, si nous laissons _bien_ le GC libérer les chaînes, alors la table de chaînes de la VM sera laissée avec des pointeurs ballants vers la mémoire libérée. Ce serait encore pire.

La table de chaînes est spéciale et nous avons besoin de support spécial pour elle. En particulier, elle a besoin d'une sorte spéciale de référence. La table devrait être capable de référer à une chaîne, mais ce lien ne devrait pas être considéré comme une racine lors de la détermination de l'accessibilité. Cela implique que l'objet référencé peut être libéré. Quand cela arrive, la référence ballante doit être fixée aussi, sorte de comme un pointeur magique, auto-nettoyant. Cet ensemble particulier de sémantiques survient assez fréquemment pour qu'il ait un nom : une [**référence faible**][weak].

[weak]: https://fr.wikipedia.org/wiki/Référence_faible

Nous avons déjà implicitement implémenté la moitié du comportement unique de la table de chaînes par vertu du fait que nous ne la traversons _pas_ durant le marquage. Cela signifie qu'elle ne force pas les chaînes à être accessibles. La pièce restante est d'effacer tous pointeurs ballants pour les chaînes qui sont libérées.
Pour retirer les références aux chaînes inaccessibles, nous avons besoin de savoir quelles chaînes _sont_ inaccessibles. Nous ne savons pas cela jusqu'à après que la phase de marquage a complété. Mais nous ne pouvons pas attendre jusqu'à après que la phase de balayage soit faite parce que d'ici là les objets -- et leurs bits de marque -- ne sont plus autour pour vérifier. Donc le bon moment est exactement entre les phases de marquage et de balayage.

^code sweep-strings (1 before, 1 after)

La logique pour retirer les chaînes sur-le-point-d'être-supprimées existe dans une nouvelle fonction dans le module "table".

^code table-remove-white-h (2 before, 2 after)

L'implémentation est ici :

^code table-remove-white

Nous marchons chaque entrée dans la table. La table d'internement de chaînes utilise seulement la clé de chaque entrée -- c'est basiquement un hash _set_ pas une hash _map_. Si le bit de marque de l'objet chaîne clé n'est pas mis, alors c'est un objet blanc qui est à moments d'être balayé au loin. Nous le supprimons de la table de hachage d'abord et assurons ainsi que nous ne verrons aucun pointeur ballant.

## Quand Collecter

Nous avons un ramasse-miettes mark-sweep pleinement fonctionnel maintenant. Quand le drapeau de test de stress est activé, il est appelé tout le temps, et avec la journalisation activée aussi, nous pouvons le regarder faire sa chose et voir qu'il réclame en effet de la mémoire. Mais, quand le drapeau de test de stress est éteint, il ne court jamais du tout. Il est temps de décider quand le collecteur devrait être invoqué durant l'exécution normale du programme.

Autant que je peux dire, cette question est pauvrement répondue par la littérature. Quand les ramasse-miettes furent d'abord inventés, les ordinateurs avaient une quantité minuscule, fixe de mémoire. Beaucoup des premiers papiers de GC supposaient que vous mettiez de côté quelques milliers de mots de mémoire -- en d'autres termes, la plupart d'elle -- et invoquiez le collecteur chaque fois que vous étiez à court. Simple.

Les machines modernes ont des gigas de RAM physique, cachés derrière l'abstraction de mémoire virtuelle encore plus large du système d'exploitation, qui est partagée parmi une flopée d'autres programmes tous se battant pour leur morceau de mémoire. Le système d'exploitation laissera votre programme demander autant qu'il veut et ensuite paginer dedans et dehors depuis le disque quand la mémoire physique devient pleine. Vous ne "tombez jamais vraiment à court" de mémoire, vous devenez juste plus lent et plus lent.

### Latence et débit

Cela n'a plus de sens d'attendre jusqu'à ce que vous "deviez", pour courir le GC, donc nous avons besoin d'une stratégie de timing plus subtile. Pour raisonner à propos de ceci plus précisément, il est temps d'introduire deux nombres fondamentaux utilisés lors de la mesure de la performance d'un gestionnaire de mémoire : _débit_ (throughput) et _latence_ (latency).

Chaque langage géré paie un prix de performance comparé à la désallocation explicite, auteur-utilisateur. Le temps passé à libérer réellement la mémoire est le même, mais le GC passe des cycles à trouver _quelle_ mémoire libérer. C'est du temps _non_ passé à courir le code de l'utilisateur et faire du travail utile. Dans notre implémentation, c'est l'entièreté de la phase de marquage. Le but d'un ramasse-miettes sophistiqué est de minimiser ce surcoût.

Il y a deux métriques clés que nous pouvons utiliser pour mieux comprendre ce coût :

- **Débit** est la fraction totale de temps passée à courir le code utilisateur versus faire du travail de ramasse-miettes. Disons que vous courez un programme clox pour dix secondes et il passe une seconde de cela à l'intérieur de `collectGarbage()`. Cela signifie que le débit est 90% -- il a passé 90% du temps à courir le programme et 10% sur le surcoût GC.

    Le débit est la mesure la plus fondamentale parce qu'elle suit le coût total du surcoût de collection. Tout le reste étant égal, vous voulez maximiser le débit. Jusqu'à ce chapitre, clox n'avait aucun GC du tout et ainsi <span name="hundred">100%</span> de débit. C'est assez dur à battre. Bien sûr, cela venait à la légère dépense de tomber potentiellement à court de mémoire et planter si le programme de l'utilisateur courait assez longtemps. Vous pouvez regarder le but d'un GC comme fixer ce "glitch" tout en sacrifiant aussi peu de débit que possible.

<aside name="hundred">

Bien, pas _exactement_ 100%. Il mettait encore bien les objets alloués dans une liste chaînée, donc il y avait un minuscule surcoût pour mettre ces pointeurs.

</aside>

- **Latence** est le plus long morceau _continu_ de temps où le programme de l'utilisateur est complètement mis en pause pendant que le ramasse-miettes arrive. C'est une mesure de comment "grossier" (chunky) le collecteur est. La latence est une métrique entièrement différente du débit.

    Considérez deux courses d'un programme clox qui prennent toutes deux dix secondes. Dans la première course, le GC démarre une fois et passe une seconde solide dans `collectGarbage()` en une collection massive. Dans la seconde course, le GC est invoqué cinq fois, chacune pour un cinquième de seconde. La quantité _totale_ de temps passée à collecter est encore une seconde, donc le débit est 90% dans les deux cas. Mais dans la seconde course, la latence est seulement 1/5ème de seconde, cinq fois moins que dans la première.

<span name="latency"></span>

<img src="image/garbage-collection/latency-throughput.png" alt="Une barre représentant le temps d'exécution avec des tranches pour courir le code utilisateur et courir le GC. La plus large tranche GC est la latence. La taille de toutes les tranches de code utilisateur est le débit." />

<aside name="latency">

La barre représente l'exécution d'un programme, divisée en temps passé à courir le code utilisateur et temps passé dans le GC. La taille de la plus grande tranche unique de temps courant le GC est la latence. La taille de toutes les tranches de code utilisateur additionnées est le débit.

</aside>

Si vous aimez les analogies, imaginez que votre programme est une boulangerie vendant du pain frais aux clients. Le débit est le nombre total de baguettes chaudes, croustillantes que vous pouvez servir aux clients en un seul jour. La latence est combien de temps le client le plus malchanceux a à attendre en ligne avant qu'il soit servi.

<span name="dishwasher">Courir</span> le ramasse-miettes est comme fermer la boulangerie temporairement pour passer à travers toute la vaisselle, trier la sale de la propre, et ensuite laver les utilisées. Dans notre analogie, nous n'avons pas de plongeurs dédiés, donc pendant que cela se passe, aucune cuisson n'arrive. Le boulanger est en train de laver.

<aside name="dishwasher">

Si chaque personne représente un thread, alors une optimisation évidente est d'avoir des threads séparés courant le ramasse-miettes, vous donnant un **ramasse-miettes concurrent**. En d'autres termes, embauchez quelques plongeurs pour nettoyer pendant que d'autres cuisinent. C'est comment les GCs très sophistiqués fonctionnent parce qu'il laisse bien les boulangers -- les threads travailleurs -- continuer de courir le code utilisateur avec peu d'interruption.

Cependant, la coordination est requise. Vous ne voulez pas qu'un plongeur attrape un bol hors des mains d'un boulanger ! Cette coordination ajoute du surcoût et beaucoup de complexité. Les collecteurs concurrents sont rapides, mais difficiles à implémenter correctement.

<img src="image/garbage-collection/baguette.png" class="above" alt="Une baguette." />

</aside>

Vendre moins de miches de pain par jour est mauvais, et faire s'asseoir et attendre n'importe quel client particulier pendant que vous nettoyez toute la vaisselle l'est aussi. Le but est de maximiser le débit et minimiser la latence, mais il n'y a pas de repas gratuit, même à l'intérieur d'une boulangerie. Les ramasse-miettes font différents compromis entre combien de débit ils sacrifient et de latence ils tolèrent.

Être capable de faire ces compromis est utile parce que différents programmes utilisateurs ont différents besoins. Un travail par lot de nuit qui génère un rapport depuis un téraoctet de données a juste besoin d'obtenir autant de travail fait aussi vite que possible. Le débit est reine. Pendant ce temps, une app courant sur le smartphone d'un utilisateur a besoin de toujours répondre immédiatement à l'entrée utilisateur pour que glisser sur l'écran se sente <span name="butter">beurré</span> doux. L'app ne peut pas geler pour quelques secondes pendant que le GC patauge dans le tas.

<aside name="butter">

Clairement l'analogie de boulangerie me monte à la tête.

</aside>

Comme auteur de ramasse-miettes, vous contrôlez une partie du compromis entre débit et latence par votre choix d'algorithme de collection. Mais même au sein d'un algorithme unique, nous avons beaucoup de contrôle sur _combien fréquemment_ le collecteur court.

Notre collecteur est un <span name="incremental">**GC stop-the-world**</span> ce qui signifie que le programme de l'utilisateur est mis en pause jusqu'à ce que le processus de ramasse-miettes entier ait complété. Si nous attendons un long moment avant que nous courions le collecteur, alors un grand nombre d'objets morts s'accumuleront. Cela mène à une pause très longue pendant que le collecteur court, et ainsi une latence élevée. Donc, clairement, nous voulons courir le collecteur vraiment fréquemment.

<aside name="incremental">

En contraste, un **ramasse-miettes incrémental** peut faire une petite collection, ensuite courir un peu de code utilisateur, ensuite collecter un peu plus, et ainsi de suite.

</aside>

Mais chaque fois que le collecteur court, il passe un peu de temps à visiter les objets vivants. Cela ne _fait_ pas vraiment quelque chose d'utile (à part assurer qu'ils ne sont pas incorrectement supprimés). Le temps visitant les objets vivants est du temps ne libérant pas de mémoire et aussi du temps ne courant pas le code utilisateur. Si vous courez le GC _vraiment_ fréquemment, alors le programme de l'utilisateur n'a pas assez de temps pour même générer de nouveaux déchets pour que la VM collecte. La VM passera tout son temps à revisiter obsessivement le même ensemble d'objets vivants encore et encore, et le débit souffrira. Donc, clairement, nous voulons courir le collecteur vraiment *in*fréquemment.

En fait, nous voulons quelque chose au milieu, et la fréquence de quand le collecteur court est l'un de nos principaux boutons pour régler le compromis entre latence et débit.

### Tas auto-ajustable

Nous voulons que notre GC coure assez fréquemment pour minimiser la latence mais assez infréquemment pour maintenir un débit décent. Mais comment trouvons-nous l'équilibre entre ceux-ci quand nous n'avons aucune idée de combien de mémoire le programme de l'utilisateur a besoin et combien souvent il alloue ? Nous pourrions refiler le problème à l'utilisateur et le forcer à choisir en exposant des paramètres de réglage GC. Beaucoup de VMs font cela. Mais si nous, les auteurs de GC, ne savons pas comment bien le régler, les chances sont bonnes que la plupart des utilisateurs ne le sauront pas non plus. Ils méritent un comportement par défaut raisonnable.

Je serai honnête avec vous, ce n'est pas mon aire d'expertise. J'ai parlé à un nombre de hackers de GC professionnels -- c'est quelque chose sur quoi vous pouvez construire une carrière entière -- et lu beaucoup de la littérature, et toutes les réponses que j'ai obtenues étaient... vagues. La stratégie que j'ai fini par choisir est commune, assez simple, et (j'espère !) assez bonne pour la plupart des usages.

L'idée est que la fréquence du collecteur s'ajuste automatiquement basé sur la taille vivante du tas. Nous suivons le nombre total d'octets de mémoire gérée que la VM a alloué. Quand cela va au-dessus de quelque seuil, nous déclenchons un GC. Après cela, nous notons combien d'octets de mémoire restent -- combien n'ont _pas_ été libérés. Ensuite nous ajustons le seuil à quelque valeur plus grande que cela.

Le résultat est que comme la quantité de mémoire vivante augmente, nous collectons moins fréquemment afin d'éviter de sacrifier le débit en re-traversant la pile grandissante d'objets vivants. Comme la quantité de mémoire vivante descend, nous collectons plus fréquemment pour que nous ne perdions pas trop de latence en attendant trop longtemps.

L'implémentation requiert deux nouveaux champs de comptabilité dans la VM.

^code vm-fields (1 before, 1 after)

Le premier est un total courant du nombre d'octets de mémoire gérée que la VM a alloué. Le second est le seuil qui déclenche la prochaine collection. Nous les initialisons quand la VM démarre.

^code init-gc-fields (1 before, 2 after)

Le seuil de départ ici est <span name="lab">arbitraire</span>. C'est similaire à la capacité initiale que nous avons prise pour nos divers tableaux dynamiques. Le but est de ne pas déclencher les premiers quelques GCs _trop_ rapidement mais aussi de ne pas attendre trop longtemps. Si nous avions quelques programmes Lox du monde réel, nous pourrions profiler ceux-ci pour régler cela. Mais puisque tout ce que nous avons sont des programmes jouets, j'ai juste pris un nombre.

<aside name="lab">

Un défi avec l'apprentissage des ramasse-miettes est qu'il est _très_ dur de découvrir les meilleures pratiques dans un environnement de laboratoire isolé. Vous ne voyez pas comment un collecteur performe réellement à moins que vous le courriez sur le genre de programmes du monde réel, larges, désordonnés pour lesquels il est réellement prévu. C'est comme régler une voiture de rallye -- vous devez la sortir sur la course.

</aside>

Chaque fois que nous allouons ou libérons un peu de mémoire, nous ajustons le compteur par ce delta.

^code updated-bytes-allocated (1 before, 1 after)

Quand le total traverse la limite, nous courons le collecteur.

^code collect-on-next (2 before, 1 after)

Maintenant, finalement, notre ramasse-miettes fait réellement quelque chose quand l'utilisateur court un programme sans notre drapeau de diagnostic caché activé. La phase de balayage libère les objets en appelant `reallocate()`, ce qui abaisse la valeur de `bytesAllocated`, donc après que la collection complète, nous savons combien d'octets vivants restent. Nous ajustons le seuil du prochain GC basé sur cela.

^code update-next-gc (1 before, 2 after)

Le seuil est un multiple de la taille du tas. De cette façon, comme la quantité de mémoire que le programme utilise grandit, le seuil bouge plus loin pour limiter le temps total passé à re-traverser l'ensemble vivant plus large. Comme d'autres nombres dans ce chapitre, le facteur d'échelle est basiquement arbitraire.

^code heap-grow-factor (1 before, 2 after)

Vous voudriez régler cela dans votre implémentation une fois que vous auriez quelques vrais programmes sur lesquels le benchmarker. Juste maintenant, nous pouvons au moins journaliser quelques-unes des statistiques que nous avons. Nous capturons la taille du tas avant la collection.

^code log-before-size (1 before, 1 after)

Et ensuite affichons les résultats à la fin.

^code log-collected-amount (1 before, 1 after)

De cette façon nous pouvons voir combien le ramasse-miettes a accompli pendant qu'il courait.

## Bugs de Ramasse-miettes

En théorie, nous avons tout fini maintenant. Nous avons un GC. Il démarre périodiquement, collecte ce qu'il peut, et laisse le reste. Si c'était un manuel typique, nous essuierions la poussière de nos mains et nous prélasserions dans la lueur douce de l'édifice de marbre sans défaut que nous avons créé.

Mais je vise à vous enseigner non juste la théorie des langages de programmation mais la réalité parfois douloureuse. Je vais rouler une bûche pourrie et vous montrer les vilains bugs qui vivent dessous, et les bugs de ramasse-miettes sont vraiment certains des invertébrés les plus grossiers là-bas.

Le travail du collecteur est de libérer les objets morts et préserver les vivants. Les erreurs sont faciles à faire dans les deux directions. Si la VM échoue à libérer les objets qui ne sont pas nécessaires, elle fuit lentement de la mémoire. Si elle libère un objet qui est en usage, le programme de l'utilisateur peut accéder à de la mémoire invalide. Ces échecs ne causent souvent pas immédiatement un plantage, ce qui rend difficile pour nous de tracer en arrière dans le temps pour trouver le bug.

Ceci est rendu plus dur par le fait que nous ne savons pas quand le collecteur courra. Tout appel qui alloue éventuellement un peu de mémoire est un endroit dans la VM où une collection pourrait arriver. C'est comme les chaises musicales. À n'importe quel point, le GC pourrait arrêter la musique. Chaque objet alloué sur le tas unique que nous voulons garder a besoin de trouver une chaise rapidement -- être marqué comme une racine ou stocké comme une référence dans quelque autre objet -- avant que la phase de balayage vienne pour l'éjecter du jeu.

Comment est-il possible pour la VM d'utiliser un objet plus tard -- un que le GC lui-même ne voit pas ? Comment la VM peut-elle le trouver ? La réponse la plus commune est par un pointeur stocké dans quelque variable locale sur la pile C. Le GC marche les piles de valeurs et CallFrame de la _VM_, mais la pile C est <span name="c">cachée</span> à lui.

<aside name="c">

Notre GC ne peut pas trouver les adresses dans la pile C, mais beaucoup le peuvent. Les ramasse-miettes conservateurs regardent tout à travers la mémoire, incluant la pile native. Le plus bien connu de cette variété est le [**ramasse-miettes Boehm–Demers–Weiser**][boehm], habituellement juste appelé le "collecteur Boehm". (Le chemin le plus court vers la célébrité en CS est un nom de famille qui est alphabétiquement tôt pour qu'il apparaisse premier dans les listes triées de noms.)

[boehm]: https://en.wikipedia.org/wiki/Boehm_garbage_collector

Beaucoup de GCs précis marchent la pile C aussi. Même ceux-là doivent être prudents à propos des pointeurs vers les objets vivants qui existent seulement dans les _registres CPU_.

</aside>

Dans les chapitres précédents, nous avons écrit du code apparemment sans but qui poussait un objet sur la pile de valeurs de la VM, faisait un petit travail, et ensuite le dépilait juste après. La plupart du temps, j'ai dit que c'était pour le bénéfice du GC. Maintenant vous voyez pourquoi. Le code entre pousser et dépiler alloue potentiellement de la mémoire et peut ainsi déclencher un GC. Nous devions nous assurer que l'objet était sur la pile de valeurs pour que la phase de marquage du collecteur le trouve et le garde vivant.

J'ai écrit l'implémentation clox entière avant de la séparer en chapitres et d'écrire la prose, donc j'ai eu plein de temps pour trouver tous ces coins et débusquer la plupart de ces bugs. Le code de test de stress que nous avons mis au début de ce chapitre et une assez bonne suite de tests étaient très utiles.

Mais j'ai fixé seulement la _plupart_ d'entre eux. J'en ai laissé une paire dedans parce que je veux vous donner un indice de ce que c'est que de rencontrer ces bugs dans la nature. Si vous activez le drapeau de test de stress et courez quelques programmes Lox jouets, vous pouvez probablement trébucher sur quelques-uns. Donnez-lui un essai et _voyez si vous pouvez en fixer n'importe lesquels vous-mêmes_.

### Ajouter à la table de constantes

Vous êtes très susceptibles de frapper le premier bug. La table de constantes que chaque morceau possède est un tableau dynamique. Quand le compilateur ajoute une nouvelle constante à la table de la fonction courante, ce tableau peut avoir besoin de grandir. La constante elle-même peut aussi être quelque objet alloué sur le tas comme une chaîne ou une fonction imbriquée.

Le nouvel objet étant ajouté à la table de constantes est passé à `addConstant()`. À ce moment, l'objet peut être trouvé seulement dans le paramètre à cette fonction sur la pile C. Cette fonction ajoute l'objet à la table de constantes. Si la table n'a pas assez de capacité et a besoin de grandir, elle appelle `reallocate()`. Cela déclenche à son tour un GC, qui échoue à marquer le nouvel objet constant et ainsi le balaie juste avant que nous ayons une chance de l'ajouter à la table. Plantage.

La correction, comme vous avez vu dans d'autres endroits, est de pousser la constante sur la pile temporairement.

^code add-constant-push (1 before, 1 after)

Une fois que la table de constantes contient l'objet, nous le dépilons de la pile.

^code add-constant-pop (1 before, 1 after)

Quand le GC marque les racines, il marche la chaîne de compilateurs et marque chacune de leurs fonctions, donc la nouvelle constante est accessible maintenante. Nous avons besoin d'un include pour appeler dans la VM depuis le module "chunk".

^code chunk-include-vm (1 before, 2 after)

### Interner les chaînes

Voici en un autre similaire. Toutes les chaînes sont internées dans clox, donc chaque fois que nous créons une nouvelle chaîne, nous l'ajoutons aussi à la table d'internement. Vous pouvez voir où cela va. Puisque la chaîne est toute neuve, elle n'est accessible nulle part. Et redimensionner la piscine de chaînes peut déclencher une collection. Encore, nous allons de l'avant et planquons la chaîne sur la pile d'abord.

^code push-string (2 before, 1 after)

Et ensuite la dépilons une fois qu'elle est sûrement nichée dans la table.

^code pop-string (1 before, 2 after)

Cela assure que la chaîne est sûre pendant que la table est redimensionnée. Une fois qu'elle survit à cela, `allocateString()` la retournera à quelque appelant qui peut alors prendre la responsabilité d'assurer que la chaîne est encore accessible avant que la prochaine allocation tas se produise.

### Concaténer les chaînes

Un dernier exemple : Là-bas dans l'interpréteur, l'instruction `OP_ADD` peut être utilisée pour concaténer deux chaînes. Comme elle le fait avec les nombres, elle dépile les deux opérandes de la pile, calcule le résultat, et pousse cette nouvelle valeur de retour sur la pile. Pour les nombres c'est parfaitement sûr.

Mais concaténer deux chaînes requiert d'allouer un nouveau tableau de caractères sur le tas, ce qui peut à son tour déclencher un GC. Puisque nous avons déjà dépilé les chaînes opérandes à ce point, elles peuvent potentiellement être manquées par la phase de marquage et être balayées au loin. Au lieu de les dépiler de la pile avidement, nous les jetons un coup d'œil (peek).

^code concatenate-peek (1 before, 2 after)

De cette façon, elles traînent encore sur la pile quand nous créons la chaîne résultat. Une fois que c'est fait, nous pouvons sûrement les dépiler et les remplacer avec le résultat.

^code concatenate-pop (1 before, 1 after)

Celles-là étaient toutes assez faciles, spécialement parce que je vous ai _montré_ où la correction était. En pratique, les _trouver_ est la partie dure. Tout ce que vous voyez est un objet qui _devrait_ être là mais n'est pas. Ce n'est pas comme d'autres bugs où vous cherchez le code qui _cause_ quelque problème. Vous cherchez l'_absence_ de code qui échoue à _prévenir_ un problème, et c'est une recherche beaucoup plus dure.

Mais, pour le moment au moins, vous pouvez vous reposer facile. Autant que je sache, nous avons trouvé tous les bugs de collection dans clox, et maintenant nous avons un ramasse-miettes mark-sweep fonctionnel, robuste, auto-réglable.

<div class="challenges">

## Défis

1.  La structure d'en-tête Obj au sommet de chaque objet a maintenant trois champs : `type`, `isMarked`, et `next`. Combien de mémoire ceux-là prennent-ils (sur votre machine) ? Pouvez-vous venir avec quelque chose de plus compact ? Y a-t-il un coût à l'exécution à faire ainsi ?

2.  Quand la phase de balayage traverse un objet vivant, elle efface le champ `isMarked` pour le préparer pour le prochain cycle de collection. Pouvez-vous venir avec une approche plus efficace ?

3.  Mark-sweep est seulement un d'une variété d'algorithmes de ramasse-miettes là-bas. Explorez ceux-là en remplaçant ou augmentant le collecteur actuel avec un autre. De bons candidats à considérer sont le comptage de référence, l'algorithme de Cheney, ou l'algorithme mark-compact Lisp 2.

</div>

<div class="design-note">

## Note de Conception : Collecteurs Générationnels

Un collecteur perd du débit s'il passe un long moment à re-visiter des objets qui sont encore vivants. Mais il peut augmenter la latence s'il évite de collecter et accumule une large pile de déchets à travers laquelle patauger. Si seulement il y avait quelque moyen de dire quels objets étaient susceptibles d'être à longue vie et les quels ne l'étaient pas. Alors le GC pourrait éviter de revisiter ceux à longue vie aussi souvent et nettoyer les éphémères plus fréquemment.

Il s'avère qu'il y a en quelque sorte. Il y a beaucoup d'années, les chercheurs en GC ont rassemblé des métriques sur la durée de vie des objets dans des programmes courant dans le monde réel. Ils ont suivi chaque objet quand il était alloué, et éventuellement quand il n'était plus nécessaire, et ensuite graphé combien de temps les objets tendaient à vivre.

Ils ont découvert quelque chose qu'ils ont appelé l'**hypothèse générationnelle**, ou le terme beaucoup moins plein de tact **mortalité infantile**. Leur observation était que la plupart des objets sont à très courte vie mais une fois qu'ils survivent au-delà d'un certain âge, ils tendent à rester dans les parages tout à fait un long moment. Plus long un objet _a_ vécu, plus longtemps il vivra probablement _continuer_. Cette observation est puissante parce qu'elle leur a donné une poignée sur comment partitionner les objets dans des groupes qui bénéficient de collections fréquentes et ceux qui ne le font pas.

Ils ont conçu une technique appelée **ramasse-miettes générationnel**. Cela fonctionne comme ceci : Chaque fois qu'un nouvel objet est alloué, il va dans une région spéciale, relativement petite du tas appelée la "pouponnière" (nursery). Puisque les objets tendent à mourir jeunes, le ramasse-miettes est invoqué <span name="nursery">fréquemment</span> sur les objets juste dans cette région.

<aside name="nursery">

Les pouponnières sont aussi habituellement gérées utilisant un collecteur copieur qui est plus rapide à allouer et libérer les objets qu'un collecteur mark-sweep.

</aside>

Chaque fois que le GC court sur la pouponnière est appelé une "génération". Tous objets qui ne sont plus nécessaires sont libérés. Ceux qui survivent sont maintenant considérés une génération plus vieux, et le GC suit cela pour chaque objet. Si un objet survit un certain nombre de générations -- souvent juste une collection unique -- il devient _titularisé_. À ce point, il est copié hors de la pouponnière dans une région de tas beaucoup plus large pour les objets à longue vie. Le ramasse-miettes court sur cette région aussi, mais beaucoup moins fréquemment puisque les chances sont bonnes que la plupart de ces objets seront encore vivants.

Les collecteurs générationnels sont un beau mariage de données empiriques -- l'observation que les durées de vie d'objet ne sont _pas_ distribuées également -- et de conception d'algorithme intelligente qui prend avantage de ce fait. Ils sont aussi conceptuellement assez simples. Vous pouvez penser à l'un comme juste deux GCs réglés séparément et une politique assez simple pour déplacer les objets de l'un à l'autre.

</div>
