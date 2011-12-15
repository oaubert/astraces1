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
/* For remoting */

import flash.events.EventDispatcher;

import mx.collections.ArrayCollection;
import mx.logging.ILogger;
import mx.logging.Log;
import mx.rpc.remoting.RemoteObject;

/**
 * Usage:
 * - at application start, initialize the trace with the uid and possibly the URI:
 *   myTrace = new Trace(uri='http:...', uid=loggedUser.id);
 * - to log an Obsel:
 *   myTrace.trace("PresenceStart", { email: loggedUser.mail, surname: loggedUser.firstname, name: loggedUser.lastName });
 */
[Bindable]
public class Trace extends EventDispatcher
{
    /**
     * Shared RemoteObject
     */
    public static var traceRemoteObject: RemoteObject;

    private var logger:ILogger = Log.getLogger("com.ithaca.traces.Trace");

    public var uri: String = "";
    public var uid: int = 0;

    public var obsels: ArrayCollection;

    public var fusionedObselTypes: Object = new Object();
    private var fusionBuffer: Vector.<Obsel> = new Vector.<Obsel>();
    public var lastObsel: Obsel = null;

    /* If True, automatically synchronize with the KTBS */
    public var autosync: Boolean = true;

    public function twoDigits(n: int): String
    {
        if (n < 10)
            return "0" + n.toString();
        else
            return n.toString();
    }

    public function Trace(uid: int = 0, uri: String = ""): void
    {
        var d: Date = new Date();
        // FIXME: debug for the moment (since KTBS is not used):
        if (uri == "")
            uri = "trace-" + d.fullYear + twoDigits(d.month + 1) + twoDigits(d.date) + twoDigits(d.hours) + twoDigits(d.minutes) + twoDigits(d.seconds) + "-" + uid;
        this.uri = uri;
        this.uid = uid;
        this.obsels = new ArrayCollection()
    }

    /**
     * Update the given trace from a TTL serialization.
     *
     * If reset is true, then first remove all existing obsels from
     * the trace.
     */
    public function updateFromRDF(ttl: String, reset: Boolean = true): void
    {
        if (reset)
            this.obsels.removeAll();

        //we split the ttl on each "." line (kind of an "end of instruction" in ttl (?))
        var ar:Array = ttl.split(/\.\s*$/m);

        for each (var l: String in ar)
        {
            // Append the trailing . again to get a valid TTL serialization.
            l = l + "\n.\n";
            //logger.info("Parsing\n=====================================" + l + "\n============================");

            var obs: Obsel = new Obsel("temp");
            obs.updateFromRDF(l);

            //if the initialization from the ttl chunk is ok, we add the obsel to the trace
            if (obs.type != "temp")
                this.addObsel(obs);
        }
    }

    public function get remote(): RemoteObject
    {
        return traceRemoteObject;
    }

    public static function init_remote(server: String): void
    {
        // Initialise RemoteObject
        traceRemoteObject = new RemoteObject();
        traceRemoteObject.endpoint=server;
        traceRemoteObject.destination = "ObselService";
        traceRemoteObject.makeObjectsBindable=true;
        traceRemoteObject.showBusyCursor=false;
    }

    /**
     * Declare an obsel type that should be fusioned.
     *
     * For obsels that can be generated in sequential quantities (such
     * as the variation of the position of a slider), generating one
     * event for each position change is too heavy and generated many
     * obsels.
     *
     * We can declare this kind of type as
     * FusionedTypes. Trace.trace() will then bufferize obsels of
     * given type, until an obsel of a different type is sent. In this
     * case, the buffer obsels will be concatenated into a single
     * Fusioned<Type>, which will possess List<prop> attributes for
     * each <prop> property of the original obsels. The List<prop>
     * attributes will contain the list of successive values.
     */
    public function addFusionedType(typ: String): void
    {
        this.fusionedObselTypes[typ] = true;
    }

    public function addObsel(obsel: Obsel): Obsel
    {
        if (obsel.uid == 0)
            obsel.uid = this.uid;

        obsel.trace = this;

        this.obsels.addItem(obsel);

        if (this.autosync)
        {
            obsel.toSGBD();
        }
        return obsel;
    }
    public function delObsel(obsel :Obsel):void
    {
        obsel.trace = this;
        if(this.autosync)
        {
            obsel.deleteObselSGBD();
        }
    }
    public function updObsel(obsel:Obsel):void
    {
        obsel.trace = this;

        if(this.autosync)
        {
            obsel.updateObselSGBD();
        }
    }

    /**
     * Return the set of obsels matching type.
     */
    public function filter(type: String): ArrayCollection
    {
        var result: ArrayCollection = new ArrayCollection();

        for each (var obs: Obsel in this.obsels)
        {
            if (obs.type == type)
            {
                result.addItem(obs);
            }
        }
        return result;
    }

    override public function toString(): String
    {
        return "Trace with " + this.obsels.length + " element(s)";
    }

    /**
     * Flush fusion buffer
     *
     * Create a new Obsel by gathering data from fusionBuffer
     * contents. It begin is the begin time of the first obsel, its
     * end time is the begin time of the last obsel.
     */
    private function flushFusionBuffer(): void
    {
        var prop: String;
        var ref: Obsel;

        if (this.fusionBuffer.length == 0)
            return;

        ref = this.fusionBuffer[0];

        /* Use first obsel as reference */
        var o: Obsel = new Obsel("Fusioned" + ref.type,
                                 ref.uid,
                                 null,
                                 ref.begin,
                                 this.fusionBuffer[this.fusionBuffer.length - 1].begin);
        for (prop in ref.props)
        {
            o.props[prop + "List"] = new Array();
        }

        /* Fusion data */
        for each (var obs: Obsel in this.fusionBuffer)
        {
            for (prop in ref.props)
            {
                o.props[prop + "List"].push(obs.props[prop]);
            }
        }
        addObsel(o);
        /* Clear fusion buffer */
        /* 4294967295 : default value for splice(), from the doc:
           http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/Vector.html#splice%28%29 */
        fusionBuffer.splice(0, 4294967295);
    }

    /**
     * Flush possibly buffered data.
     */
    public function flush(): void
    {
        if (this.fusionBuffer.length != 0)
        {
            flushFusionBuffer();
        }
    }

    /**
     * Convenience method to quickly create an Obsel and
     * add it to the trace.
     */
    public function trace(type: String, props: Object = null, begin: Number = 0, end: Number = 0): Obsel
    {
        var o: Obsel;

        try
        {
            o = new Obsel(type, uid, props, begin, end);

            if (this.lastObsel != null && this.lastObsel.type != type)
                /* Flush buffer */
                this.flushFusionBuffer();

            if (fusionedObselTypes.hasOwnProperty(type))
                this.fusionBuffer.push(o)
            else
                /* Append new obsel */
                this.addObsel(o);

            this.lastObsel = o;
            //logger.debug("\n===\n" + o.toRDF() + "\n===\n");
        }
        catch (error:Error)
        {
            logger.debug("Exception in trace: " + error);
        }
        return o;
    }

    /**
     * Return a Tab-Separated-Values representation of the trace
     *
     * The table features one column per attribute.
     */

    public function toTSV(): String
    {
        var o: Obsel;
        var fields: Array = new Array();
        var type2col: Object = new Object();
        var row: Vector.<String> = new Vector.<String>();
        var data: Array = new Array();
        var p: String;

        fields.push("ktbs:begin");
        fields.push("ktbs:end");
        fields.push("ktbs:type");
        fields.push("ktbs:subject");
        for (var i: int = 0; i < fields.length ; i++)
            type2col[i] = i;

        /* Convert a Trace to Tab-Separated-Value format */
        for each (o in this.obsels)
        {
            row.splice(0, 4294967295);
            row.length = fields.length;

            row[0] = Obsel.value2repr(o.begin);
            row[1] = Obsel.value2repr(o.end);
            row[2] = Obsel.value2repr(o.type);
            row[3] = Obsel.value2repr(o.uid);
            for (p in o.props)
            {
                if (! type2col.hasOwnProperty(p))
                {
                    fields.push(p);
                    type2col[p] = fields.length - 1;
                }
                row[type2col[p]] = Obsel.value2repr(o.props[p], false, true)
            }
            for (i = 0; i < row.length; i++)
                if (row[i] === null)
                    row[i] = "-";
            // Print row
            data.push(row.join("\t"));
        }
        data.unshift(fields.join("\t"));
        return data.join("\n");
    }
}

}
