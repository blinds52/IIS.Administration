// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.


namespace Microsoft.IIS.Administration.WebServer.HttpResponseHeaders
{
    using System;

    public class CustomHeaderId
    {
        private const string PURPOSE = "WebServer.HttpResponseHeaders.CustomHeader";
        private const char DELIMITER = '\n';

        private const uint NAME_INDEX = 0;
        private const uint PATH_INDEX = 1;
        private const uint SITE_ID_INDEX = 2;

        public string Name { get; private set; }
        public string Path { get; private set; }
        public long? SiteId { get; private set; }
        public string Uuid { get; private set; }

        public CustomHeaderId(string uuid)
        {
            if (string.IsNullOrEmpty(uuid)) {
                throw new ArgumentNullException("uuid");
            }

            var info = Core.Utils.Uuid.Decode(uuid, PURPOSE).Split(DELIMITER);

            string name = info[NAME_INDEX];
            string path = info[PATH_INDEX];
            string siteId = info[SITE_ID_INDEX];

            if (!string.IsNullOrEmpty(path)) {

                if (string.IsNullOrEmpty(siteId)) {
                    throw new ArgumentNullException("siteId");
                }

                this.Path = path;
                this.SiteId = long.Parse(siteId);
            }
            else if (!string.IsNullOrEmpty(siteId)) {

                this.SiteId = long.Parse(siteId);
            }

            this.Name = name;
            this.Uuid = uuid;
        }

        public CustomHeaderId(long? siteId, string path, string name)
        {

            if (string.IsNullOrEmpty(name)) {
                throw new ArgumentNullException("name");
            }

            if (!string.IsNullOrEmpty(path) && siteId == null) {
                throw new ArgumentNullException("siteId");
            }

            this.Name = name;
            this.Path = path;
            this.SiteId = siteId;

            string encodableSiteId = this.SiteId == null ? "" : this.SiteId.Value.ToString();

            this.Uuid = Core.Utils.Uuid.Encode($"{this.Name}{DELIMITER}{this.Path}{DELIMITER}{encodableSiteId}", PURPOSE);
        }
    }
}
