pragma Singleton

//  Qué herramientas hay y cómo se agrupan.
//
//  Sólo la tabla. El carril y la barra de opciones son dos vistas distintas
//  que la leen, y así no hay dos listas de herramientas que se vayan
//  separando. Los grupos son por lo que hacen: un carril de veinte iconos
//  seguidos no se aprende nunca.

import QtQuick
import Quickshell

Singleton {
    readonly property var grupos: [
        [ { id: "lapiz", ico: "lapiz", nombre: "lápiz", tecla: "B" },
          { id: "goma", ico: "goma", nombre: "goma", tecla: "E" },
          { id: "cubo", ico: "cubo", nombre: "cubo de relleno", tecla: "G" },
          { id: "cuentagotas", ico: "cuentagotas", nombre: "cuentagotas (o Alt)", tecla: "I" } ],

        [ { id: "linea", ico: "linea", nombre: "línea", tecla: "L" },
          { id: "rectangulo", ico: "rectangulo", nombre: "rectángulo", tecla: "U" },
          { id: "elipse", ico: "elipse", nombre: "elipse", tecla: "O" },
          { id: "degradado", ico: "degradado", nombre: "degradado tramado", tecla: "D" } ],

        [ { id: "sombreado", ico: "sombreado", nombre: "sombreado por rampa", tecla: "S" },
          { id: "sustituye", ico: "sustituye", nombre: "sustituir color", tecla: "R" },
          { id: "difumina", ico: "difumina", nombre: "difuminar" },
          { id: "mancha", ico: "mancha", nombre: "manchar" },
          { id: "aclara", ico: "aclara", nombre: "aclarar" },
          { id: "quema", ico: "quema", nombre: "quemar" } ],

        [ { id: "marco", ico: "marco", nombre: "marco rectangular", tecla: "M" },
          { id: "elipseSel", ico: "elipseSel", nombre: "marco elíptico" },
          { id: "lazo", ico: "lazo", nombre: "lazo libre", tecla: "Q" },
          { id: "lazoPoli", ico: "poligono", nombre: "lazo poligonal" },
          { id: "varita", ico: "varita", nombre: "varita mágica", tecla: "W" },
          { id: "porColor", ico: "paleta", nombre: "seleccionar por color" } ],

        [ { id: "mover", ico: "mover", nombre: "mover", tecla: "V" },
          { id: "mano", ico: "mano", nombre: "mano (o Espacio)", tecla: "H" } ]
    ]


    /** El nombre largo de una herramienta, para la barra de opciones. */
    function nombre(id) {
        for (let g = 0; g < grupos.length; g++)
            for (let i = 0; i < grupos[g].length; i++)
                if (grupos[g][i].id === id) return grupos[g][i].nombre
        return id
    }
}
