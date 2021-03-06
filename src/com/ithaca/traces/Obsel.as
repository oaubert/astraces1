/**
 * Copyright Université Lyon 1 / Université Lyon 2 (2009,2010,2011)
 *
 * <ithaca@liris.cnrs.fr>
 *
 * This file is part of Visu.
 *
 * This software is a computer program whose purpose is to provide an
 * enriched videoconference application.
 *
 * Visu is a free software subjected to a double license.
 * You can redistribute it and/or modify since you respect the terms of either
 * (at least one of the both license) :
 * - the GNU Lesser General Public License as published by the Free Software Foundation;
 *   either version 3 of the License, or any later version.
 * - the CeCILL-C as published by CeCILL; either version 2 of the License, or any later version.
 *
 * -- GNU LGPL license
 *
 * Visu is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * Visu is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with Visu.  If not, see <http://www.gnu.org/licenses/>.
 *
 * -- CeCILL-C license
 *
 * This software is governed by the CeCILL-C license under French law and
 * abiding by the rules of distribution of free software.  You can  use,
 * modify and/ or redistribute the software under the terms of the CeCILL-C
 * license as circulated by CEA, CNRS and INRIA at the following URL
 * "http://www.cecill.info".
 *
 * As a counterpart to the access to the source code and  rights to copy,
 * modify and redistribute granted by the license, users are provided only
 * with a limited warranty  and the software's author,  the holder of the
 * economic rights,  and the successive licensors  have only  limited
 * liability.
 *
 * In this respect, the user's attention is drawn to the risks associated
 * with loading,  using,  modifying and/or developing or reproducing the
 * software by the user in light of its specific status of free software,
 * that may mean  that it is complicated to manipulate,  and  that  also
 * therefore means  that it is reserved for developers  and  experienced
 * professionals having in-depth computer knowledge. Users are therefore
 * encouraged to load and test the software's suitability as regards their
 * requirements in conditions enabling the security of their systems and/or
 * data to be ensured and,  more generally, to use and operate it in the
 * same conditions as regards security.
 *
 * The fact that you are presently reading this means that you have had
 * knowledge of the CeCILL-C license and that you accept its terms.
 *
 * -- End of licenses
 */
package com.ithaca.traces
{
//import com.ithaca.visu.model.vo.ObselVO;

import com.ithaca.traces.model.vo.SGBDObsel;

// From as3corelibs
import com.adobe.serialization.json.JSON;

import flash.events.EventDispatcher;

import mx.rpc.IResponder;

import mx.logging.ILogger;
import mx.logging.Log;

import mx.rpc.AbstractOperation;
import mx.rpc.AbstractService;
import mx.rpc.AsyncToken;
import mx.rpc.IResponder;
import mx.rpc.Responder;
import mx.rpc.events.FaultEvent;
import mx.rpc.events.ResultEvent;
import mx.utils.StringUtil;

[Bindable]
public class Obsel extends EventDispatcher implements IResponder
{
    public var type: String = "Generic";

    /* Begin and end time */
    public var begin: Number;
    public var end: Number;
    public var uid: uint = 0;
    /* Dictionary holding the various obsel properties
    * (dependant on the type).
    */
    public var props: Object = new Object();

    /* These will be initialized once the Obsel has been added to
    * a trace */
    public var uri: String = "";
    public var trace: Trace = null;

    public var sgbdobsel: SGBDObsel = null;

    private static var quote_regexp: RegExp = /"/g;
    private static var eol_regexp: RegExp = /[\r\n]/g;

    private static var logger:ILogger = Log.getLogger("com.ithaca.traces.Obsel");

    public function Obsel(my_type: String, uid: int = 0, props: Object=null, begin: Number = 0, end: Number = 0)
    {
        this.type = my_type;
        if (begin == 0)
            begin = new Date().time;
        if (end == 0)
            end = begin;
        this.begin = begin;
        this.end = end;
        this.uid = uid;
        if (props != null)
        {
            // Copy given properties
            for (var prop: String in props)
                this.props[prop] = props[prop];
        }
    }

    /**
     * Clone the current obsel
     *
     * Note: it does not copy the Trace and uri values. These fields
     * are initialized when the Obsel is added to the trace.
     */
    public function clone(): Obsel
    {
        return new Obsel(this.type, this.uid, this.props, this.begin, this.end);
    }

    // IResponder interface implementation
    public function result(data: Object): void
    {
        var event: ResultEvent = data as ResultEvent;
        if (event != null && event.result != null)
        {
            this.sgbdobsel = event.result as SGBDObsel;
            logger.debug("Received SGBDObsel " + this.sgbdobsel.id + "type is "+ this.sgbdobsel.type);
        }
        else
        {
            logger.debug("Error in RO.result code: null event");
        }
    }

    public function fault(info: Object): void
    {
        var event: FaultEvent = info as FaultEvent;
        if (event != null)
        {
            logger.debug("Error in RO code " + event.fault);
        }
        else
        {
            logger.debug("Error in RO fault code: null event");
        }
    }

    /**
     * Return the obsel's trace Uri
     *
     * <p>Depending on its initialization path, it will get the
     * information either from the parent trace or from the sgbdobsel.</p>
     */
    public function get traceUri(): String
    {
        if (trace != null)
            return trace.uri;
        else if (this.sgbdobsel != null)
            return this.sgbdobsel.trace;
        else
            return "";
    }

    /**
     * Save the obsel data to the SGBD
     */
    public function toSGBD(): void
    {
        if (! this.trace.remote)
        {
            logger.error("RemoteObject for traces is not initialized. Cannot save Obsel.");
            return;
        }
        this.sgbdobsel = new SGBDObsel();
        this.sgbdobsel.trace = this.trace.uri;
        this.sgbdobsel.type = this.type;
        this.sgbdobsel.begin = new Date(this.begin);
        this.sgbdobsel.rdf = this.toRDF();

        var call: AsyncToken = this.trace.remote.getOperation("addObsel").send(this.sgbdobsel);
        call.addResponder(this);
    }
    public function deleteObselSGBD():void
    {
        var call: AsyncToken = this.trace.remote.getOperation("deleteObsel").send(this.sgbdobsel);
        call.addResponder(this);
    }
    public function updateObselSGBD():void
    {
        if (! this.trace.remote)
        {
            logger.error("RemoteObject for traces is not initialized. Cannot update Obsel.");
            return;
        }
        this.sgbdobsel.begin = new Date(this.begin);
        this.sgbdobsel.trace = this.trace.uri;
        this.sgbdobsel.rdf = this.toRDF();
        this.sgbdobsel.type = this.type;
        var call: AsyncToken = this.trace.remote.getOperation("updateObsel").send(this.sgbdobsel);
        call.addResponder(this);
    }
    override public function toString(): String
    {
        var s: String = "Obsel " + this.type + " [" + this.uid + "] (" + this.begin + " - " + this.end + ")\n{" ;
        for (var p: String in this.props)
            s = s + p + "=" + this.props[p].toString().replace("\r", "\\r").replace("\n", "\\n") + ", "
        s = s + "}"
        return s;
    }

    /**
     * Convert a value to its turtle representation
     *
     * If isTime is true, then the value is treated as a timestamp.
     * If oneLine is true, then all serializations (even for Arrays) will be rendered as one-liners.
     */
    public static function value2repr(val: *, isTime: Boolean = false, oneLine: Boolean = false): String
    {
        var res: String = "";

        if (val == null)
        {
            res = '"[null value]"';
        }
        else if (val is Number || val is int || val is uint)
        {
            if (isTime)
            {
                // Not used for the moment, but we could have special handling here.
                res = val.toString();
            }
            else
            {
                res = val.toString();
            }
        }
        else if (val is Array)
        {
            var formatted: Array = val.map(function (o: Object, i: int, a: Array): String {
                                              return value2repr(o);
                                           })
            if (oneLine)
                res = "( " + formatted.join(", ") + " )";
            else
                res = "(\n        " + formatted.join("\n        ") + ")";
        }
        else
        {
            // FIXME: quoting is not complete: http://www.w3.org/TeamSubmission/turtle/#sec-strings
            // \uXXXX and \UXXXX is missing.
            // NOTE: multiple replace() calls are not efficient, since we walk through the same string multiple times.
            res = '"' + val.toString().replace('\\', '\\\\').replace(quote_regexp, '\\"').replace(eol_regexp, "\\n").replace("\t", "\\t").replace("\r", "\\r") + '"';
        }
        return res;
    }

    /**
     * Convert a turtle representation to its value
     */
    private static function repr2value(s: String, isTime: Boolean = false): *
    {
        var res: *;
        var a: Array;

        if (s == '"[null value]"')
        {
            res = null;
        }
        else
        {
            a = s.match(/^"(.*)"$/);
            if (a)
            {
                // String
                res = a[1].replace('\\"', '"').replace('\\n', "\n").replace("\\t", "\t").replace("\\r", "\r").replace('\\\\', '\\');
            }
            else
            {
                a = s.match(/^<(.*)>$/);
                if (a)
                {
                    // Reference. Consider as a string for the moment.
                    res = a[1];
                }
                else {
                    a = s.match(/^\s*"(.*)"\^\^\<(.+)>$/);
                    if (a)
                    {
                        if (a[2] == "http://www.w3.org/2001/XMLSchema#integer")
                            res = Number(a[1])
                        else
                            // Consider as a string
                            res = a[1].replace('\\"', '"').replace('\\n', "\n").replace("\\t", "\t").replace("\\r", "\r").replace('\\\\', '\\');
                    }
                    else
                    {
                        // Should be an integer
                        res = Number(s);
                        //if (isTime)
                        //    res = res / TIME_FACTOR;
                    }
                }
            }
        }
        return res;
    }

    /**
     * Generate the RDF/turtle representation of the obsel
     *
     * @return The generated RDF
     */
    public function toRDF(): String
    {
        var res: Array = new Array();

        res.push("@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .",
            "@prefix ktbs: <http://liris.cnrs.fr/silex/2009/ktbs/> .",
            "@prefix : <../visu/> .",
            "",
            "[] a :" + this.type + " ;",
            "  ktbs:hasTrace <" + traceUri + "> ;",
            "  ktbs:hasBegin " + value2repr(this.begin, true) + " ;",
            "  ktbs:hasEnd " + value2repr(this.end, true) + " ;",
            '  ktbs:hasSubject "' + this.uid + '" ;');
        for (var prop: String in this.props)
        {
            var name: String = prop;
            if (prop.indexOf(":") == -1)
            {
                /* No : in property name: old convention foo -> :hasFoo */
                name = ":has" + prop.charAt(0).toUpperCase() + prop.substr(1);
            }
            res.push("  " + name + " " + value2repr(this.props[prop], (prop.indexOf('timestamp') == -1 ? false : true) ) + " ;");
        }
        res.push(".");

        return res.join("\n");
    }

    /**
     * Update the Obsel data from a RDF/turtle serialization
     *
     * <p>Some constraints on the formatting:
     *     * semicolons must end each line (except for lists)
     *     * lists are begun with a single ( as data at the end of a
     *       line, then one value per line, then ended with );
     *     * the obsel must end with a . alone on a line.
     *
     * @param rdf The RDF string
     */
    public function updateFromRDF(rdf: String): void
    {
        var a: Array = null;
        var inData: Boolean = false;
        var listData: Array = null;

        for each (var l: String in rdf.split(/\n/))
        {
            /* FIXME: now that we support new convention, we should
             * store the prefix/namespace information, in the trace
             * possibly, to be able to re-encode it */
            l = StringUtil.trim(l);
            // Single . on a line by itself
            if (l == ".")
                break;
            // Ignore empty lines
            if (l == "")
                continue;
            //trace("Processing " + l);

            // Type declaration
            a = l.match(/(.+)\s+a\s+(\w*):(\w+)\s*;/);
            if (a)
            {
                var prefix: String = a[2];
                if (prefix == "")
                    this.type = a[3];
                else
                    this.type = prefix + ":" + a[3];
                // FIXME: add trace URI as basename?
                this.uri = a[1];
                a = null;
                inData = true;
                continue;
            }
            if (! inData)
                continue;

            // Handle continued list data
            if (listData)
            {
                a=l.match(/(.*)\s*\)\s*;$/);
                if (a)
                {
                    // End of list
                    if (StringUtil.trim(a[1]).length != 0)
                    {
                        // There is a last item
                        listData.push(repr2value(StringUtil.trim(a[1])));
                    }
                    listData = null;
                    continue;
                }
                listData.push(repr2value(l));
                continue;
            }

            a = l.match(/^(\w*):(\w+)\s+(.+?)\s*([;\.]?)$/);
            if (a)
            {
                /*
                for (var i: int = 0 ; i < a.length ; i++)
                {
                logger.debug("Property " + i + ": " + a[i]);
                }
                */
                var idprefix: String = a[1];
                var identifier: String = a[2];
                var data: String = a[3];
                var eol: String = a[4];

                var name: String = idprefix + ":" + identifier;
                if (idprefix == "" && identifier.substr(0, 3) == "has")
                {
                    /* Ascending compatibility with the old model
                     * convention of having the foo property
                     * encoded as :hasFoo */
                    /* To encode back, the principle is: if there
                     * is no : in the name, then it follows the
                     * old convention, and has to be encoded as
                     * hasFoo */
                    name = identifier.charAt(3).toLowerCase() + identifier.substr(4);
                }

                if (data == "(")
                {
                    // Beginning of a list
                    // FIXME: there may be data just after the (, this case is not taken into account here.
                    listData = new Array();
                    this.props[name] = listData;
                    if (eol == ".")
                        break
                    else
                        continue;
                }
                else switch (name)
                {
                case "ktbs:hasBegin":
                    // Convert seconds back to ms
                    this.begin = repr2value(data, true);
                    break;
                case "ktbs:hasEnd":
                    // Convert seconds back to ms
                    this.end = repr2value(data, true);
                    // Let's hope actionscript will use this
                    // break to get out the switch scope, and
                    // not out of the loop.
                    break;
                case "ktbs:hasSubject":
                    this.uid = repr2value(data);
                    break;
                case "ktbs:hasTrace":
                    // We should check against the destination trace URI/id
                    break;
                default:
                    if (name.indexOf("timestamp") > -1)
                        // Time value
                        this.props[name] = repr2value(data, true)
                    else
                        this.props[name] = repr2value(data);
                    break;
                }
                if (eol == ".")
                    break;
            }
            else
            {
                logger.error("Error in fromRDF : " + l);
            }

        }
    }

    public function get rdf(): String
    {
        return this.toRDF();
    }

    /**
     * Generate an Obsel from a RDF/turtle serialization
     *
     * See updateFromRDF for constraints on TTL format.
     *
     * @param rdf The RDF string
     *
     * @return The obsel
     */
    public static function fromRDF(data: String): Obsel
    {
        var o: Obsel = new Obsel("Generic");
        o.updateFromRDF(data);
        return o;
    }

    /**
     * Generate the JSON representation of the obsel
     *
     * @param context: an object containing the @context information
     * from the containing trace, used to resolve qnames
     *
     * @return The generated JSON
     */
    public function toJSON(context: Object = null): *
    {
        var res: Object = new Object();

        // FIXME: use basename(uri)
        res['@id'] = this.uri;
        res['@type'] = this.type;
        res['begin'] = this.begin;
        res['end'] = this.end;
        res['subject'] = this.uid;
        for (var prop: String in this.props)
        {
            var name: String = prop;
            if (prop.indexOf(":") == -1)
            {
                /* No : in property name: old convention foo -> :hasFoo */
                name = ":has" + prop.charAt(0).toUpperCase() + prop.substr(1);
            }
            res[name] = this.props[prop];
        }

        return res;
    }

    public function toJSONString(context: Object = null): String
    {
        return JSON.encode(this.toJSON(context));
    }

    public function updateFromJSON(source: *): void
    {
        if (source is String)
            source = JSON.decode(source);

        var json_mapping: Object = { '@id': 'uri',
                                     '@type': 'type',
                                     'begin': 'begin',
                                     'end': 'end',
                                     'subject': 'uid'
                                   };

        for (var prop: String in source)
        {
            var name: String = prop;
            if (json_mapping.hasOwnProperty(name))
            {
                this[json_mapping[name]] = source[name];
            }
            else
            {
                // No standard attribute. Store in props
                this.props[name] = source[name];
            }
        }
    }
}
}
